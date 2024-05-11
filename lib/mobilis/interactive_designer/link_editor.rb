# frozen_string_literal: true

module Mobilis::InteractiveDesigner
  def self.add_edit_links_states(instance)
    instance.instance_eval do
      event :go_edit_links do
        transition [:edit_links_select_project] => :edit_links
      end

      event :go_edit_links_select_project do
        transition [:main_menu] => :edit_links_select_project
        transition [:edit_links] => :edit_links_select_project
      end

      state :edit_links_select_project do
        def display
          puts "Select Project"
          fancy_tp projects, "name", "type", links: lambda { |p| p.links.join ", " }
        end

        def choices
          [
            {name: "return to Main Menu", value: -> { go_main_menu }},
            *(projects.map { |project|
                links_txt = project.links.join ", "
                {
                  name: "Edit '#{project.name}' links (#{links_txt})",
                  value: -> do
                    @selected_project = project
                    go_edit_links
                  end
                }
              })
          ]
        end
      end

      state :edit_links do
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
        def choices = false
        def display = false
      end
    end
  end
end
