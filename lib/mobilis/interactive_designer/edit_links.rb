# frozen_string_literal: true

require "mel/scene-fsm"

module Mobilis::InteractiveDesigner
  class KafkaEdit < Mobilis::SceneFSM

    state_machine :state, initial: :kafka_instance_edit do
      event :go_edit_kafka_project do
        transition [
          :edit_project_menu
        ] => :kafka_project_edit
      end

      event :go_main_menu do
        transition [:kafka_instance_edit] => :main_menu
      end

      state :kafka_instance_edit do
        def display
          @selected_kafka_project.display
        end

        def choices
          [
            { name: "return to Main Menu", value: -> { go_main_menu } }
            # {name: "Toggle API mode", value: -> { go_toggle_rails_api_mode }},
            # {name: "Toggle UUID primary keys mode", value: -> { go_toggle_rails_uuid_primary_keys }},
            # {name: "Add Model", value: -> { go_rails_add_model }},
            # {name: "Add Controller", value: -> { go_rails_add_controller }},
            # {name: "Add linked postgres database", value: -> { go_rails_add_linked_postgres }}
          ]
        end

        def action = false
      end
    end
  end
end
