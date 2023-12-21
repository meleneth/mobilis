# frozen_string_literal: true

module Mobilis::InteractiveDesigner
  class MainMenu < Mobilis::SceneFSM
    extend Forwardable
    def_delegators :project, :projects, :load_from_file
    attr_accessor :project

    attr_accessor :selected_rails_project

    def select_rails_project_for_editing(rails_project)
      puts "Selecting rails project for editing"
      puts rails_project.name
      @selected_rails_project = rails_project
      go_rails_project_edit
    end

    state_machine :state, initial: :main_menu do
      Mobilis::InteractiveDesigner.add_project_menu_states self
      Mobilis::InteractiveDesigner.add_rails_model_edit_states self
      Mobilis::InteractiveDesigner.add_rails_project_edit_states self
      Mobilis::InteractiveDesigner.add_project_edit_menu_states self

      #after_transition any => any do |designer|
      #  puts "o0o VVVV ---- VVVV o0o"
      #  puts "-- Switched state to #{designer.state_name} --"
      #  puts "o0o ^^^^ ---- ^^^^ o0o"
      #end

      event :go_build do
        transition [:main_menu] => :build
      end

      event :go_quit do
        transition [:main_menu] => :quit
      end

      event :go_show_configuration do
        transition [:main_menu] => :show_configuration
      end

      event :go_edit_project_menu do
        transition [:main_menu] => :edit_project_menu
      end

      event :go_back do
        transition [:edit_rails_project] => :edit_project_menu
        transition [:edit_generic_project] => :main_menu
        transition [:add_project_menu] => :main_menu
        transition [:generate] => :main_menu
        transition [:main_menu] => :finished
      end

      event :go_finished do
        transition any => :finished
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

      event :go_edit_links_select_project do
        transition [:main_menu] => :edit_links_select_project
        transition [:edit_links] => :edit_links_select_project
      end

      event :go_edit_links do
        transition [:edit_links_select_project] => :edit_links
      end

      state :main_menu do
        def display
          fancy_tp projects, "name", "type", options: lambda { |p| p.options.join ", " }
        end

        def choices
          menu_items = [
            { name: "reload all code", value: -> { reload! } },
            { name: "[m] Add project", value: -> { go_add_project_menu } },
            { name: "[m] Edit existing project", value: -> { go_edit_project_menu } },
            { name: "[m] Show configuration", value: -> { go_show_configuration } }
          ]
          if projects.length > 1
            menu_items.concat([
                                { name: "[m] edit links", value: -> { go_edit_links_select_project } }
                              ])
          end
          if projects.length > 0
            menu_items.concat([
                                { name: "Save mproj.json", value: -> { go_save_project } },
                                { name: "Generate", value: -> { go_generate } },
                                { name: "Build", value: -> { go_build } }
                              ])
          end
          menu_items.concat([
                              { name: "quit", value: -> { go_quit } }
                            ])
          menu_items
        end
      end

      state :edit_links_select_project do
        def display
          puts "Select Project"
          fancy_tp projects, "name", "type", links: lambda { |p| p.links.join ", " }
        end

        def choices
          [
            { name: "return to Main Menu", value: -> { go_main_menu } },
            *(projects.map { |project|
                links_txt = project.links.join ", "
                {
                  name: "Edit '#{project.name}' links (#{links_txt})",
                  value: -> { visit_submachine Mobilis::InteractiveDesigner::EditLinks.new(project) }
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
      end

      state :finished do
        def still_running?
          false
        end
        def choices = false
        def display = false

      end

      state :generate do
        def action
          project.generate_files
          go_back
        end

        def choices = false
        def display = false
      end

      state :build do
        def action
          project.build
          go_back
        end
        def choices = false
        def display = false

      end

      state :save_project do
        def action
          project.save_project
          go_back
        end
        def choices = false
        def display = false

      end

      state :show_configuration do
        def action
          project.show
          go_back
        end
        def choices = false
        def display = false

      end

      state :quit do
        def still_running?
          false
        end
        def choices = false
        def display = false

      end
    end

    # display, choices, and action methods all change per-state
    def new_relic_license_key
      ENV.fetch "NEW_RELIC_LICENSE_KEY", false
    end

    def fancy_tp(data, *options)
      TablePrint::Config.set(:max_width, [160])
      printer = TablePrint::Printer.new(data, options)
      lines = printer.table_print
      decobox(lines)
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

    def project
      @project ||= ::Mobilis::Project.new
    end
  end
end
