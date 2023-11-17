# frozen_string_literal: true

module Mobilis::InteractiveDesigner
  class AddProjectMenu < Mel::SceneFSM
    extend Forwardable
    attr_reader :project
    def_delegators :project, :projects, :load_from_file

    def initialize(project)
      @project = project
      setup()
    end

    state_machine :state, initial: :add_project_menu do
      event :go_quit do
        transition [:main_menu] => :quit
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

      event :go_add_mysql_instance do
        transition [:add_project_menu] => :add_mysql_instance
      end

      event :go_add_redis_instance do
        transition [:add_project_menu] => :add_redis_instance
      end

      event :go_back do
        transition [:edit_rails_project] => :edit_project_menu
        transition [:edit_generic_project] => :main_menu
        transition [:add_project_menu] => :go_finished
      end

      event :go_finished do
        transition any => :finished
      end

      event :go_add_rack_project do
        transition [:add_project_menu] => :add_rack_project
      end

      event :go_add_localgem_project do
        transition [:add_project_menu] => :add_localgem_project
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

      state :finished do
        def display = false

        def choices = false

        def action = false

        def still_running?
          false
        end
      end

      state :add_prime_stack_rails_project do
        def display
          puts "Creates a new rails project, using the prime stack"
          puts "includes rspec haml factory_bot"
        end

        def choices = false

        def action
          project_name = prompt.ask("new Prime Stack Rails project name:")
          rails_project = project.add_prime_stack_rails_project project_name
          editor_machine = editor_machine_for(rails_project)
          visit_submachine editor_machine
          go_main_menu
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

      state :quit do
        def display = false

        def choices = false

        def action = false

        def still_running?
          false
        end
      end
    end
  end
end
