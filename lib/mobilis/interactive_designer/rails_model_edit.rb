# frozen_string_literal: true

require "mel/scene-fsm"

module Mobilis::InteractiveDesigner
  def self.add_rails_model_edit_states(instance)
    instance.instance_eval do
      event :go_rails_model_edit do
        transition %i[
          rails_model_edit
          rails_model_add_field_references_select_model
          rails_model_add_field_enter_name
        ] => :rails_model_edit
      end

      event :go_rails_project_add_model do
        transition [:rails_project_edit] => :rails_project_add_model
      end

      event :go_rails_project_add_controller do
        transition [:rails_project_edit] => :rails_add_controller
      end

      event :go_rails_controller_edit do
        transition [:rails_project_add_controller] => :rails_controller_edit
      end

      event :go_rails_model_edit do
        transition [:rails_project_add_model] => :rails_model_edit
      end

      event :go_rails_project_add_linked_postgres do
        transition [:rails_project_edit] => :rails_project_add_linked_postgres
      end

      event :go_rails_model_add_field do
        transition [:rails_model_edit] => :rails_model_add_field
      end

      event :go_rails_field_edit do
        transition %i[
          rails_model_add_field
          rails_model_edit
        ] => :rails_field_edit
      end

      event :go_rails_model_add_field_select_type do
        transition [:rails_model_edit] => :rails_model_add_field_select_type
      end

      event :go_rails_model_add_field_references_select_model do
        transition [:rails_model_add_field_select_type] => :rails_model_add_field_references_select_model
      end

      event :go_rails_model_add_field_enter_name do
        transition [:rails_model_add_field_select_type] => :rails_model_add_field_enter_name
      end

      state :rails_model_edit do
        def display
          puts @selected_rails_project.name
          fancy_tp @selected_rails_model.fields, "name", type: lambda { |f| f.type.name }
        end

        def default
        end

        def choices
          [
            {
              name: "return to Main Menu",
              value: -> { go_main_menu }
            },
            {
              name: "Toggle timestamps",
              value: -> { go_toggle_rails_model_timestamps }
            },
            {
              name: "Add field",
              value: -> { go_rails_model_add_field_select_type }
            },
            {
              name: "return to rails project edit",
              value: -> { go_rails_project_edit }
            },
            *(@selected_rails_model.fields.map do |field|
              {
                name: "Edit '#{field.name}' :#{field.type.name} field",
                value: -> { @selected_rails_field = field ; go_rails_field_edit }
              }
            end)
          ]
        end

        def action = false
      end

      state :rails_project_toggle_api_mode do
        def display
          Mobilis.logger.info "Toggled rails API mode for '#{@selected_rails_project.name}'"
        end

        def action
          @selected_rails_project.toggle_rails_api_mode
          go_rails_project_edit
        end

        def choices = false
      end

      state :rails_project_add_linked_postgres do
        def display
          spacer
        end

        def action
          db_name = prompt.ask("new linked postgresql instance name:", default: "#{@selected_rails_project}.name}-db")
          @selected_rails_project.add_linked_postgresql_instance db_name
          go_rails_project_edit
        end

        def choices = false
      end

      state :rails_model_add_field do
        def display
          puts @selected_rails_model.name
        end

        def action
          name = prompt.ask("new field name:")
          @selected_rails_field = @selected_rails_model.add_field name
          go_rails_model_edit
        end

        def choices = false
      end

      state :rails_project_toggle_uuid_primary_keys do
        def display
          Mobilis.logger.info "Toggled UUID primary keys for '#{@selected_rails_project.name}'"
        end

        def action
          @selected_rails_project.toggle_rails_uuid_primary_keys
          go_edit_rails_project
        end

        def choices = false
      end

      state :rails_project_add_model do
        def display
          ap @selected_rails_project.models.collect { |x| x[:name] }
        end

        def action
          name = prompt.ask("new model name")
          @selected_rails_model = @selected_rails_project.add_model name
          go_rails_model_edit
        end

        def choices = false
      end

      state :rails_model_add_field_select_type do
        def display
          ap @selected_rails_model.name
        end

        def choices
          [
            { name: "references", value: -> { go_rails_model_add_field_references_select_model } },
            *(Mobilis::NON_REFERENCE_MODEL_TYPES.map do |field|
              {
                name: "Add '#{field.name}' #{field.description} field",
                value: -> { @selected_rails_field_new_type = field ; go_rails_model_add_field_enter_name }
              }
            end)
          ]
        end
        def action = false
      end

      state :rails_model_add_field_references_select_model do
        def display
          ap @selected_rails_project.models.collect(&:name)
        end

        def choices
          [
            { name: "Return to Model Edit", value: -> { go_rails_model_edit } },
            *(@selected_rails_project.models.map do |model|
              {
                name: "Reference '#{model.name}'",
                value: -> { @selected_rails_model.add_references(model) ; go_rails_model_edit }
              }
            end)
          ]
        end

        def action = false
      end

      state :rails_model_add_field_enter_name do
        def display
          ap @selected_rails_project.models.collect(&:name)
        end

        def action
          name = prompt.ask("new #{@selected_rails_field_new_type.name} field name: ")
          @selected_rails_model.add_field(name: name, type: @selected_rails_field_new_type)
          go_rails_model_edit
        end

        def choices = false
      end

      state :rails_add_controller do
        def display
          ap @selected_rails_project.controllers.collect(&:name)
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
