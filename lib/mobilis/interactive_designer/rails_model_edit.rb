# frozen_string_literal: true

require "mel/scene-fsm"

module Mobilis::InteractiveDesigner
  class RailsModelEdit < Mel::SceneFSM
    def initialize(rails_model)
      @rails_model = rails_model
      super()
      # TODO: toggle_scaffold
      # TODO: edit name
      # TODO: delete
    end

    state_machine :state, initial: :rails_model_edit do
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

      state :rails_model_edit do
        def display
          Mobilis.logger.info "Toggled rails API mode for '#{@selected_rails_project.name}'"
        end

        def choices = false

        def action
          @selected_rails_project.toggle_rails_api_mode
          go_edit_rails_project
        end

      end

      state :toggle_rails_api_mode do
        def display
          Mobilis.logger.info "Toggled rails API mode for '#{@selected_rails_project.name}'"
        end

        def choices = false

        def action
          @selected_rails_project.toggle_rails_api_mode
          go_edit_rails_project
        end
      end

      state :rails_add_linked_postgres do
        def display
          spacer
        end

        def choices = false

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

        def choices = false

        def action
          @selected_rails_project.toggle_rails_uuid_primary_keys
          go_edit_rails_project
        end
      end

      state :rails_add_model do
        def display
          ap @selected_rails_project.models.collect { |x| x[:name] }
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
          ap @selected_rails_project.controllers.collect { |x| x[:name] }
        end

        def choices = false

        def action
          name = prompt.ask("new controller name:")
          @selected_rails_controller = answer.add_controller name
          go_edit_rails_controller
        end
      end

      state :main_edit_screen do
        def display = false

        def choice = false

        def action = false
      end
    end
  end
end
