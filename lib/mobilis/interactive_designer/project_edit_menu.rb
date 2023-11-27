# frozen_string_literal: true

module Mobilis::InteractiveDesigner
  def self.add_project_edit_menu_states(instance)
    instance.instance_eval do
      event :go_rails_app_edit_screen do
        transition [
          :edit_project_menu,
          :toggle_rails_api_mode,
          :rails_add_linked_postgres,
          :toggle_rails_uuid_primary_keys
        ] => :rails_app_edit_screen
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
            { name: "return to Main Menu", value: -> { go_main_menu } },
            *(projects.map { |project|
              case project.type
              when :rails
                {
                  name: "Edit '#{project.name}' project",
                  value: -> { select_rails_project_for_editing(project) }
                }
              else
                {
                  name: "Not supported - #{project.name}",
                  value: -> {}
                }
              end
            })
          ]
        end
      end
    end
  end
end
