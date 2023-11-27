# frozen_string_literal: true

require "mel/scene-fsm"

module Mobilis::InteractiveDesigner
  def self.add_rails_model_edit_states(instance)
    instance.instance_eval do
      event :go_edit_rails_project do
        transition [
          :edit_project_menu,
          :add_omakase_stack_rails_project,
          :add_prime_stack_rails_project,
          :toggle_rails_api_mode,
          :toggle_rails_uuid_primary_keys,
          :rails_add_linked_postgres
        ] => :edit_rails_project
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
        transition [:edit_rails_project] => :rails_add_linked_postgres
      end

      state :rails_model_edit_screen do
        def display
          @rails_project.display
        end

        def choices
          [
            { name: "return to Main Menu", value: -> { go_finished } },
            { name: "add Model", value: -> { go_toggle_rails_api_mode } },
            { name: "add Scaffold", value: -> { go_toggle_rails_uuid_primary_keys } },
            { name: "Add Model", value: -> { go_rails_add_model } },
            { name: "Add Controller", value: -> { go_rails_add_controller } },
            { name: "Add linked postgres database", value: -> { go_rails_add_linked_postgres } }
          ]
        end
      end

      state :rails_model_edit do
        def display
          Mobilis.logger.info "Toggled rails API mode for '#{@selected_rails_project.name}'"
        end

        def action
          @selected_rails_project.toggle_rails_api_mode
          go_edit_rails_project
        end
      end

      state :toggle_rails_api_mode do
        def display
          Mobilis.logger.info "Toggled rails API mode for '#{@selected_rails_project.name}'"
        end

        def action
          @selected_rails_project.toggle_rails_api_mode
          go_edit_rails_project
        end
      end

      state :rails_add_linked_postgres do
        def display
          spacer
        end

        def action
          db_name = prompt.ask("new linked postgresql instance name:", default: "#{@selected_rails_project}.name}-db")
          @selected_rails_project.add_linked_postgresql_instance db_name
          go_edit_rails_project
        end
      end

      state :toggle_rails_uuid_primary_keys do
        def display
          Mobilis.logger.info "Toggled UUID primary keys for '#{@selected_rails_project.name}'"
        end

        def action
          @selected_rails_project.toggle_rails_uuid_primary_keys
          go_edit_rails_project
        end
      end

      state :rails_add_model do
        def display
          ap @selected_rails_project.models.collect { |x| x[:name] }
        end

        def action
          name = prompt.ask("new model name")
          @selected_rails_model = add_model name
          go_edit_rails_model
        end
      end

      state :rails_add_controller do
        def display
          ap @selected_rails_project.controllers.collect { |x| x[:name] }
        end

        def action
          name = prompt.ask("new controller name:")
          @selected_rails_controller = answer.add_controller name
          go_edit_rails_controller
        end
      end
    end
  end
end
