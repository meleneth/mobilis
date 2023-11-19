# frozen_string_literal: true

require "mel/scene-fsm"

module Mobilis::InteractiveDesigner
  class KafkaInstanceEdit < Mel::SceneFSM
    def initialize rails_project
      @rails_project = rails_project
      super()
    end

    state_machine :state, initial: :kafka_instance_edit do
      event :go_edit_rails_project do
        transition [
          :edit_project_menu,
          :add_omakase_stack_rails_project,
          :add_prime_stack_rails_project,
          :toggle_rails_api_mode,
          :toggle_rails_uuid_primary_keys,
          :rails_add_linked_postgres
        ] => :rails_app_edit_screen
      end

      event :go_finished do
        transition any => :finished
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

      event :go_rails_add_linked_postgres do
        transition [:rails_app_edit_screen] => :rails_add_linked_postgres
      end

      state :kafka_instance_edit do
        def display
          @rails_project.display
        end

        def choices
          [
            {name: "return to Main Menu", value: -> { go_finished }}
            # {name: "Toggle API mode", value: -> { go_toggle_rails_api_mode }},
            # {name: "Toggle UUID primary keys mode", value: -> { go_toggle_rails_uuid_primary_keys }},
            # {name: "Add Model", value: -> { go_rails_add_model }},
            # {name: "Add Controller", value: -> { go_rails_add_controller }},
            # {name: "Add linked postgres database", value: -> { go_rails_add_linked_postgres }}
          ]
        end

        def action = false
      end

      state :toggle_rails_api_mode do
        def display
          Mobilis.logger.info "Toggled rails API mode for '#{@rails_project.name}'"
        end

        def choices = false

        def action
          @rails_project.toggle_rails_api_mode
          go_edit_rails_project
        end
      end

      state :rails_add_linked_postgres do
        def display
          spacer
        end

        def choices = false

        def action
          db_name = prompt.ask("new linked postgresql instance name:", default: "#{@rails_project}.name}-db")
          @rails_project.add_linked_postgresql_instance db_name
          go_edit_rails_project
        end
      end

      state :toggle_rails_uuid_primary_keys do
        def display
          Mobilis.logger.info "Toggled UUID primary keys for '#{@rails_project.name}'"
        end

        def choices = false

        def action
          @rails_project.toggle_rails_uuid_primary_keys
          go_edit_rails_project
        end
      end

      state :rails_add_model do
        def display
          ap @rails_project.models.collect { |x| x[:name] }
        end

        def choices = false

        def action
          name = prompt.ask("new model name")
          @rails_model = add_model name
          go_edit_rails_model
        end
      end

      state :rails_add_controller do
        def display
          ap @rails_project.controllers.collect { |x| x[:name] }
        end

        def choices = false

        def action
          name = prompt.ask("new controller name:")
          @rails_controller = answer.add_controller name
          go_edit_rails_controller
        end
      end

      state :main_edit_screen do
        def display = false

        def choice = false

        def action = false
      end

      state :finished do
        def display = false

        def choice = false

        def action = false

        def still_running?
          false
        end
      end
    end
  end
end
