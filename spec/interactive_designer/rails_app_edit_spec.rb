# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

RSpec.describe 'RailsAppEdit' do
  let(:metaproject) { build(:metaproject) }
  let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "somerails") }
  let(:fsm) { build(:fsm, project: metaproject) }
  let(:prompt) { fsm.prompt }

  def select_choice name
    show_current_location
    puts "Selecting #{name}"

    choices = fsm.choices
    if choices
      choices.each do |choice|
        return choice[:value].call if choice[:name].include? name
      end
      raise "Choice not found"
    end
    puts "Choices didn't exist"
  end

  def whereami
    puts "Machine in state: #{fsm.state}"
    expect(fsm.choices).to eq([])
  end

  def show_current_location
    puts "--- Machine in state: #{fsm.state}"
    puts fsm.choices
  end

  before do
    allow(fsm).to receive(:projects).and_return([rails_project])
    rails_project
    select_choice "Edit existing"
  end

  describe "Add linked postgres project" do
    it "Event works to edit the project" do
      fsm.selected_rails_project = rails_project
      fsm.go_rails_app_edit_screen
      expect(fsm.state).to eq "rails_app_edit_screen"
      expect(fsm.instance_variable_get(:@selected_rails_project)).to eq(rails_project)
    end
    it "allows creating linked postgres" do
      select_choice "somerails"
      expect(fsm.state).to eq "rails_app_edit_screen"
      allow(prompt).to receive(:ask).and_return "account-db"
      allow(fsm).to receive(:projects).and_return([rails_project])
      expect(rails_project).to receive(:add_linked_postgresql_instance).with("account-db")
      select_choice "Add linked postgres database"
      fsm.action
      expect(fsm.state).to eq "rails_app_edit_screen"
    end
  end

  describe "Toggle API Mode" do
    it "allows toggling of API mode" do
      expect(fsm.state).to eq "edit_project_menu"
      select_choice "somerails"
      expect(metaproject.projects[0].options).to include(:api)
      expect(fsm.state).to eq "rails_app_edit_screen"
      #  expect(rails_project).to receive(:toggle_rails_api_mode)
      select_choice "Toggle API mode"
      expect(fsm.state).to eq "toggle_rails_api_mode"
      fsm.action
      expect(metaproject.projects[0].options).not_to include(:api)
    end
  end
end
