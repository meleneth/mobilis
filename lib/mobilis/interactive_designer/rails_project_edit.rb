# frozen_string_literal: true

require "mel/scene-fsm"

module Mobilis::InteractiveDesigner
  def self.add_rails_project_edit_states(instance)
    instance.instance_eval do
      event :go_rails_project_edit do
        transition [
          :rails_project_toggle_uuid_primary_keys,
          :rails_project_add_linked_postgres,
          :rails_project_add_linked_mysql,
          :rails_project_add_linked_redis,
          :rails_project_add_index_select_model,
          :rails_project_add_index_to_model,
          :rails_model_edit
        ] => :rails_project_edit
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

      event :go_rails_project_add_linked_postgres do
        transition [:rails_project_edit] => :rails_project_add_linked_postgres
      end

      event :go_rails_project_add_linked_mysql do
        transition [:rails_project_edit] => :rails_project_add_linked_mysql
      end

      event :go_rails_project_add_linked_redis do
        transition [:rails_project_edit] => :rails_project_add_linked_redis
      end

      event :go_rails_project_toggle_api_mode do
        transition [:rails_project_edit] => :rails_project_toggle_api_mode
      end

      event :go_rails_project_toggle_uuid_primary_keys do
        transition [:rails_project_edit] => :rails_project_toggle_uuid_primary_keys
      end

      event :go_rails_project_add_index_select_model do
        transition [:rails_project_edit] => :rails_project_add_index_select_model
      end

      event :go_rails_project_add_index_to_model do
        transition [:rails_project_add_index_select_model] => :rails_project_add_index_to_model
      end

      event :go_rails_model_edit do
        transition [
          :rails_add_model,
          :rails_project_edit
        ] => :rails_model_edit
      end

      state :rails_project_edit do
        def display
          @selected_rails_project.display
        end

        def choices
          [
            {
              name: "return to Main Menu",
              value: -> { go_main_menu }
            },
            {
              name: "Toggle API mode",
              value: -> { go_rails_project_toggle_api_mode }
            },
            {
              name: "Toggle UUID primary keys mode",
              value: -> { go_rails_project_toggle_uuid_primary_keys }
            },
            {
              name: "Add Model",
              value: -> { go_rails_project_add_model }
            },
            {
              name: "Add Controller",
              value: -> { go_rails_project_add_controller }
            },
            {
              name: "Add index",
              value: -> { go_rails_project_add_index_select_model }
            },
            {
              name: "Add linked postgres database",
              value: -> { go_rails_project_add_linked_postgres }
            },
            {
              name: "Add linked mysql database",
              value: -> { go_rails_project_add_linked_mysql }
            },
            {
              name: "Add linked redis instance",
              value: -> { go_rails_project_add_linked_redis }
            },
            *(@selected_rails_project.models.map do |model|
              {
                name: "Edit '#{model.name}' model",
                value: -> do
                  @selected_rails_model = model
                  go_rails_model_edit
                end
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

        def choices = false

        def action
          @selected_rails_project.toggle_rails_api_mode
          go_rails_project_edit
        end
      end

      state :rails_project_add_linked_postgres do
        def display
          spacer
        end

        def choices = false

        def action
          db_name = prompt.ask("new linked postgresql instance name:", default: "#{@selected_rails_project.name}db")
          @selected_rails_project.add_linked_postgresql_instance db_name
          go_rails_project_edit
        end
      end

      state :rails_project_add_linked_mysql do
        def display
          spacer
        end

        def choices = false

        def action
          db_name = prompt.ask("new linked mysql instance name:", default: "#{@selected_rails_project}.name}db")
          @selected_rails_project.add_linked_mysql_instance db_name
          go_rails_project_edit
        end
      end

      state :rails_project_add_linked_redis do
        def display
          spacer
        end

        def choices = false

        def action
          db_name = prompt.ask("new linked redis instance name:", default: "#{@selected_rails_project}.name}db")
          @selected_rails_project.add_linked_redis_instance db_name
          go_rails_project_edit
        end
      end

      state :rails_project_toggle_uuid_primary_keys do
        def display
          Mobilis.logger.info "Toggled UUID primary keys for '#{@selected_rails_project.name}'"
        end

        def choices = false

        def action
          @selected_rails_project.toggle_uuid_primary_keys

          go_rails_project_edit
        end
      end

      state :rails_project_add_index_select_model do
        def display
          fancy_tp @selected_rails_project.models, "name", type: lambda { |model| model.fields.map(&:name).join ", " }
        end

        def choices
          c = [
            {
              name: "return to Main Menu",
              value: -> { go_main_menu }
            }
          ]
          @selected_rails_project.models.each do |model|
            c << {
              name: model.name,
              value: -> {
                @selected_rails_model = model
                go_rails_project_add_index_to_model
              }
            }
          end
          c
        end

        def action = false
      end

      state :rails_project_add_index_to_model do
        def display
          fancy_tp @selected_rails_project.models, "name", type: lambda { |m| model.fields.join ", " }
        end

        def choices = false

        def action
          selected = prompt.multi_select("Select fields") do |menu|
            @selected_rails_model.fields.each do |field|
              menu.choice "#{field.name} #{field.type.name}", field.name
            end
          end
          @selected_rails_model.add_index(*selected)
          go_rails_project_edit
        end
      end

      state :rails_project_add_model do
        def display
          ap @selected_rails_project.models.collect(&:name)
        end

        def choices = false

        def action
          name = prompt.ask("new model name")
          @selected_rails_model = @selected_rails_project.add_model name
          go_rails_model_edit
        end
      end

      state :rails_project_add_controller do
        def display
          ap @selected_rails_project.controllers.collect(&:name)
        end

        def choices = false

        def action
          name = prompt.ask("new controller name:")
          @rails_controller = answer.add_controller name
          go_rails_app_edit_screen
        end
      end
    end
  end
end
