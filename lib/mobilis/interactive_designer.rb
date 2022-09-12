# frozen_string_literal: true

require 'awesome_print'
require 'forwardable'
require 'state_machine'
require 'table_print'
require 'tty-prompt'

require 'mobilis/logger'
require 'mobilis/project'

module Mobilis

class InteractiveDesigner
extend Forwardable

attr_accessor :project
attr_reader :prompt

def_delegators :@project, :projects, :load_from_file

state_machine :state, initial: :intialize do

  event :go_build do
    transition [:main_menu] => :build
  end

  event :go_add_omakase_stack_rails_project do
    transition [:main_menu] => :add_omakase_stack_rails_project
  end

  event :go_add_prime_stack_rails_project do
    transition [:main_menu] => :add_prime_stack_rails_project
  end

  event :go_add_postgresql_instance do
    transition [:main_menu] => :add_postgresql_instance
  end

  event :go_add_mysql_instance do
    transition [:main_menu] => :add_mysql_instance
  end

  event :go_add_redis_instance do
    transition [:main_menu] => :add_redis_instance
  end

  event :go_back do
    transition [:edit_rails_project] => :main_menu
    transition [:edit_generic_project] => :main_menu
  end

  event :go_add_rack_project do
    transition [:main_menu] => :add_rack_project
  end

  event :go_edit_rails_project do
    transition [
      :add_omakase_stack_rails_project,
      :add_prime_stack_rails_project,
      :edit_rails_controller,
      :edit_rails_model,
      :toggle_rails_api_mode,
      :main_menu
    ] => :edit_rails_project
  end

  event :go_generate do
    transition [:main_menu] => :generate
  end

  event :go_main_menu do
    transition to: :main_menu
  end

  event :go_rails_add_model do
    transition [:edit_rails_project] => :rails_add_model
  end

  event :go_rails_add_controller do
    transition [:edit_rails_project] => :rails_add_controller
  end

  event :go_rails_edit_controller do
    transition [:rails_add_controller] => :edit_rails_controller
  end

  event :go_rails_edit_model do
    transition [:rails_add_model] => :edit_rails_model
  end

  event :go_save_project do
    transition [:main_menu] => :save_project
  end

  event :go_toggle_rails_api_mode do
    transition [:edit_rails_project] => :toggle_rails_api_mode
  end

  event :go_edit_links_select_project do
    transition [:main_menu] => :edit_links_select_project
  end

  event :go_edit_links do
    transition [:edit_links_select_project] => :edit_links
  end

  after_transition any => any do |designer|
    puts "o0o VVVV ---- VVVV o0o"
    puts "-- Switched state to #{ designer.state_name } --"
    puts "o0o ^^^^ ---- ^^^^ o0o"
  end

  state :main_menu do
    def display
      puts
      tp.set :max_width, 160
      tp projects, 'name', 'type', 'options': lambda {|p| p.options.join ", "}
      puts
    end
    def choices
      project_choices = projects.map do |project|
        { name: "Edit '#{ project.name }' project", value: -> { @selected_rails_project = project ; go_edit_rails_project } }
      end
      [
        {name: "Add prime stack rails project",    value: -> { go_add_prime_stack_rails_project }},
        {name: "Add omakase stack rails project",  value: -> { go_add_omakase_stack_rails_project }},
        {name: "Add rack3 project",                value: -> { go_add_rack_project }},
        #{ name: "Add airflow server project",      value: -> { go_add_airflow_server }},
        #{ name: "Add airflow job project",         value: -> { go_add_airflow_job_project }},
        #{ name: "Add Docker registry",             value: -> { go_add_docker_registry }},
        #{ name: "Add Vue.js project",              value: -> { go_add_vue_project }},
        #{ name: "Add flask project",               value: -> { go_add_flask_project }},
        #{ name: "Add existing git project",        value: -> { go_add_existing_git_project }},
        { name: "Add redis instance",              value: -> { go_add_redis_instance }},
        { name: "Add postgresql instance",         value: -> { go_add_postgresql_instance }},
        { name: "Add mysql instance",              value: -> { go_add_mysql_instance }},
        #{ name: "Add couchdb instance",            value: -> { go_add_couchdb_instance }},
        #{ name: "Add kafka instance",              value: -> { go_add_kafka_instance }},
        #{ name: "Add graphql instance",            value: -> { go_add_grapql_instance }},
        #{ name: "Add gitlab instance w/workers",   value: -> { go_add_gitlab_instance }},
        *project_choices,
        { name: "edit links", value: -> { go_edit_links_select_project }},
        { name: "Save mproj.json", value: -> { go_save_project }},
        { name: "Generate", value: -> { go_generate }},
        { name: "Build", value: -> { go_build }}
      ]
    end
    def action = false
  end

  state :edit_links_select_project do
    def display
      puts
      tp.set :max_width, 160
      tp projects, 'name', 'type', 'links': lambda {|p| p.links.join ", "}
      puts
    end
    def choices
      [
        {name: "return to Main Menu",          value: -> { go_main_menu }},
        *( projects.map do |project|
            links_txt = project.links.join ", "
             { name: "Edit '#{ project.name }' links (#{ links_txt })", value: -> { @selected_project = project ; go_edit_links } }
           end)
      ]
    end
    def action = false
  end

  state :edit_links do
    def display = false
    def choices = false
    def action
      selected = prompt.multi_select("Select links") do |menu|
        menu.default *@selected_project.links
        projects.each do |project|
          menu.choice project.name unless project.name == @selected_project.name
        end
      end
      @selected_project.set_links selected
      go_main_menu
    end
  end

  state :edit_rails_model do
    def display
      ap @selected_rails_project.models.collect {|x| x[:name]}
    end
    def choices
      [
        {name: "return to Main Menu",          value: -> { go_main_menu }},
        {name: "return to rails project edit", value: -> { go_edit_rails_project }},
        {name: "Toggle timestamps",            value: -> { go_toggle_rails_model_timestamps }},
        *( @selected_rails_project.models.map do |model|
             { name: "Edit '#{ model.name }' model", value: -> { @selected_rails_model = model ; go_edit_rails_model } }
           end)
      ]
    end
    def action = false
  end

  state :edit_rails_project do
    def display
      @selected_rails_project.display
    end
    def choices
      [
        {name: "return to Main Menu", value: -> { go_main_menu }},
        {name: "Toggle API mode",     value: -> { go_toggle_rails_api_mode }},
        {name: "Add Model",           value: -> { go_rails_add_model }},
        {name: "Add Controller",      value: -> { go_rails_add_controller }}
      ]
    end
    def action = false
  end

  state :add_prime_stack_rails_project do
    def display
      spacer
    end
    def choices = false
    def action
      project_name = prompt.ask("new Prime Stack Rails project name:")
      @selected_rails_project = project.add_prime_stack_rails_project project_name
      go_edit_rails_project
    end
  end

  state :add_rack_project do
    def display
      spacer
    end
    def choices = false
    def action
      project_name = prompt.ask("new Rack project name:")
      project.add_rack_project project_name
      go_main_menu
    end
  end

  state :add_omakase_stack_rails_project do
    def display
      spacer
    end
    def choices = false
    def action
      project_name = prompt.ask("new Omakase Stack Rails project name:")
      @selected_rails_project = project.add_omakase_stack_rails_project project_name
      go_edit_rails_project
    end
  end

  state :add_postgresql_instance do
    def display
      spacer
    end
    def choices = false
    def action
      project_name = prompt.ask("new postgresql instance name:")
      project.add_postgresql_instance project_name
      go_main_menu
    end
  end

  state :add_mysql_instance do
    def display
      spacer
    end
    def choices = false
    def action
      project_name = prompt.ask("new mysql instance name:")
      project.add_mysql_instance project_name
      go_main_menu
    end
  end

  state :add_redis_instance do
    def display
      spacer
    end
    def choices = false
    def action
      project_name = prompt.ask("new redis instance name:")
      project.add_redis_instance project_name
      go_main_menu
    end
  end

  state :toggle_rails_api_mode do
    def display
      Mobilis.logger.info "Toggled rails API mode for '#{ @selected_rails_project.name }'"
    end
    def choices = false
    def action
      @selected_rails_project.toggle_rails_api_mode
      go_edit_rails_project
    end
  end

  state :rails_add_model do
    def display
      ap @selected_rails_project.models.collect {|x| x[:name]}
    end
    def choices = false
    def action
      name = prompt.ask("new model name")
      @selected_rails_model = add_model name
      go_edit_rails_model
    end
  end

  state :rails_add_controller do
    def display
      ap @selected_rails_project.controllers.collect {|x| x[:name]}
    end
    def choices = false
    def action
      name = prompt.ask("new controller name:")
      @selected_rails_controller = answer.add_controller name
      go_edit_rails_controller
    end
  end

  state :generate do
    def display
      spacer
    end
    def choices = false
    def action
      project.generate_files
      go_main_menu
    end
  end

  state :build do
    def display
      spacer
    end
    def choices = false
    def action
      project.build
      go_main_menu
    end
  end

  state :save_project do
    def display
      spacer
    end
    def choices = false
    def action
      project.save_project
      go_main_menu
    end
  end
end

def initialize
  super()
  @prompt = TTY::Prompt.new
  @project = Project.new
end

##
# display, choices, and action methods all change per-state
def choose_destination
  Mobilis.logger.info "#choose_destination"
  blank_space
  spacer
  display
  spacer
  blank_space

  if some_choices = choices then
    prompt.select("Choose your Path", some_choices, per_page: 20)
  else
    Mobilis.logger.info "No choices found, running action instead"
    action
  end
end

def new_relic_license_key
  ENV.fetch "NEW_RELIC_LICENSE_KEY", false
end

def spacer
  puts "|+--------------------------------------------------------+|"
end

def blank_space
  puts ""
end

end
end
