# frozen_string_literal: true

require "awesome_print"
require "forwardable"
require "state_machine"
require "table_print"
require "tty-prompt"

require "mobilis/logger"
require "mobilis/project"

module Mobilis::InteractiveDesigner
  class MainMenu
    extend Forwardable

    attr_accessor :project
    attr_reader :prompt

    def_delegators :@project, :projects, :load_from_file

    state_machine :state, initial: :initialize do
      event :go_build do
        transition [:main_menu] => :build
      end

      event :go_add_omakase_stack_rails_project do
        transition [:add_project_menu] => :add_omakase_stack_rails_project
      end

      event :go_add_prime_stack_rails_project do
        transition [:add_project_menu] => :add_prime_stack_rails_project
      end

      event :go_add_postgresql_instance do
        transition [:add_project_menu] => :add_postgresql_instance
      end

      event :go_add_project_menu do
        transition [:main_menu] => :add_project_menu
      end

      event :go_edit_project_menu do
        transition [:main_menu] => :edit_project_menu
      end

      event :go_add_mysql_instance do
        transition [:add_project_menu] => :add_mysql_instance
      end

      event :go_add_redis_instance do
        transition [:add_project_menu] => :add_redis_instance
      end

      event :go_back do
        transition [:edit_rails_project] => :edit_project_menu
        transition [:edit_generic_project] => :main_menu
        transition [:add_project_menu] => :main_menu
      end

      event :go_add_rack_project do
        transition [:add_project_menu] => :add_rack_project
      end

      event :go_add_localgem_project do
        transition [:add_project_menu] => :add_localgem_project
      end

      event :go_generate do
        transition [:main_menu] => :generate
      end

      event :go_main_menu do
        transition to: :main_menu
      end

      event :go_save_project do
        transition [:main_menu] => :save_project
      end

      event :go_toggle_rails_api_mode do
        transition [:edit_rails_project] => :toggle_rails_api_mode
      end

      event :go_toggle_rails_uuid_primary_keys do
        transition [:edit_rails_project] => :toggle_rails_uuid_primary_keys
      end

      event :go_edit_links_select_project do
        transition [:main_menu] => :edit_links_select_project
        transition [:edit_links] => :edit_links_select_project
      end

      event :go_edit_links do
        transition [:edit_links_select_project] => :edit_links
      end

      after_transition any => any do |designer|
        puts "o0o VVVV ---- VVVV o0o"
        puts "-- Switched state to #{designer.state_name} --"
        puts "o0o ^^^^ ---- ^^^^ o0o"
      end

      state :main_menu do
        def display
          puts
          tp.set :max_width, 160
          tp projects, "name", "type", options: lambda { |p| p.options.join ", " }
          puts
        end

        def choices
          menu_items = [
            {name: "reload all code", value: -> { reload! }},
            {name: "[m] Add project", value: -> { go_add_project_menu }},
            {name: "[m] Edit existing project", value: -> { go_edit_project_menu }}
          ]
          if projects.length > 1
            menu_items.concat([
              {name: "[m] edit links", value: -> { go_edit_links_select_project }}
            ])
          end
          if projects.length > 0
            menu_items.concat([
              {name: "Save mproj.json", value: -> { go_save_project }},
              {name: "Generate", value: -> { go_generate }},
              {name: "Build", value: -> { go_build }}
            ])
          end
          menu_items
        end

        def action = false
      end

      state :edit_project_menu do
        def display
          puts
          tp.set :max_width, 160
          tp projects, "name", "type", options: lambda { |p| p.options.join ", " }
          puts
        end

        def choices
          [
            {name: "return to Main Menu", value: -> { go_main_menu }},
            *(projects.map { |project|
                {name: "Edit '#{project.name}' project", value: -> {
                                                                  @selected_rails_project = project
                                                                  go_edit_rails_project
                                                                }}
              })
          ]
        end

        def action = false
      end

      state :add_project_menu do
        def display
          puts
          tp.set :max_width, 160
          tp projects, "name", "type", options: lambda { |p| p.options.join ", " }
          puts
        end

        def choices
          [
            {name: "return to Main Menu", value: -> { go_main_menu }},
            {name: "Add prime stack rails project", value: -> { go_add_prime_stack_rails_project }},
            {name: "Add omakase stack rails project", value: -> { go_add_omakase_stack_rails_project }},
            {name: "Add rack3 project", value: -> { go_add_rack_project }},
            {name: "Add localgem project", value: -> { go_add_localgem_project }},
            # { name: "Add airflow server project",      value: -> { go_add_airflow_server }},
            # { name: "Add airflow job project",         value: -> { go_add_airflow_job_project }},
            # { name: "Add Docker registry",             value: -> { go_add_docker_registry }},
            # { name: "Add Vue.js project",              value: -> { go_add_vue_project }},
            # { name: "Add flask project",               value: -> { go_add_flask_project }},
            # { name: "Add existing git project",        value: -> { go_add_existing_git_project }},
            {name: "Add redis instance", value: -> { go_add_redis_instance }},
            {name: "Add postgresql instance", value: -> { go_add_postgresql_instance }},
            {name: "Add mysql instance", value: -> { go_add_mysql_instance }}
            # { name: "Add couchdb instance",            value: -> { go_add_couchdb_instance }},
            # { name: "Add kafka instance",              value: -> { go_add_kafka_instance }},
            # { name: "Add graphql instance",            value: -> { go_add_grapql_instance }},
            # { name: "Add gitlab instance w/workers",   value: -> { go_add_gitlab_instance }}
          ]
        end

        def action = false
      end

      state :edit_links_select_project do
        def display
          puts
          tp.set :max_width, 160
          tp projects, "name", "type", links: lambda { |p| p.links.join ", " }
          puts
        end

        def choices
          [
            {name: "return to Main Menu", value: -> { go_main_menu }},
            *(projects.map do |project|
                links_txt = project.links.join ", "
                {name: "Edit '#{project.name}' links (#{links_txt})", value: -> {
                                                                               @selected_project = project
                                                                               go_edit_links
                                                                             }}
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
            menu.default(*@selected_project.links)
            projects.each do |project|
              menu.choice project.name unless project.name == @selected_project.name
            end
          end
          @selected_project.set_links selected
          go_edit_links_select_project
        end
      end

      state :edit_rails_model do
        def display
          ap @selected_rails_project.models.collect { |x| x[:name] }
        end

        def choices
          [
            {name: "return to Main Menu", value: -> { go_main_menu }},
            {name: "return to rails project edit", value: -> { go_edit_rails_project }},
            {name: "Toggle timestamps", value: -> { go_toggle_rails_model_timestamps }},
            *(@selected_rails_project.models.map do |model|
                {name: "Edit '#{model.name}' model", value: -> {
                                                              @selected_rails_model = model
                                                              go_edit_rails_model
                                                            }}
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
            {name: "Toggle API mode", value: -> { go_toggle_rails_api_mode }},
            {name: "Toggle UUID primary keys mode", value: -> { go_toggle_rails_uuid_primary_keys }},
            {name: "Add Model", value: -> { go_rails_add_model }},
            {name: "Add Controller", value: -> { go_rails_add_controller }},
            {name: "Add postgres database", value: -> { go_rails_add_linked_postgres }}
          ]
        end

        def action = false
      end

      state :add_prime_stack_rails_project do
        def display
          puts "Creates a new rails project, using the prime stack"
          puts "includes rspec haml factory_bot"
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
          puts "Creates a new rack project, with a minimal script"
        end

        def choices = false

        def action
          project_name = prompt.ask("new Rack project name:")
          project.add_rack_project project_name
          go_main_menu
        end
      end

      state :add_localgem_project do
        def display
          puts "Creates a new local gem project, generated via native bundler gem"
        end

        def choices = false

        def action
          project_name = prompt.ask("new local gem project name:")
          project.add_localgem_project project_name
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

      if some_choices = choices
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

    def reload!(print = true)
      puts "Reloading ..." if print
      # Main project directory.
      root_dir = File.expand_path("../..", __dir__)
      # Directories within the project that should be reloaded.
      reload_dirs = %w[lib]
      # Loop through and reload every file in all relevant project directories.
      reload_dirs.each do |dir|
        Dir.glob("#{root_dir}/#{dir}/**/*.rb").each { |f| load(f) }
      end
      # Return true when complete.
      true
    end
  end
end
