# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

RSpec.describe "FSM Acceptance" do
  let(:fsm) do
    id = Mobilis::InteractiveDesigner::MainMenu.new
    id.go_main_menu
    id
  end
  let(:prompt) { fsm.prompt }

  def select_choice name
    fsm.choices.each do |choice|
      return choice[:value].call if choice[:name].include? name
    end
  end

  def whereami
    expect(fsm.choices).to eq([])
  end

  def add_prime_rails_project name
    select_choice "Add project"
    select_choice "Add prime stack"
    allow(prompt).to receive(:ask).and_return name
    fsm.action
    select_choice "return to Main Menu"
  end

  def edit_project name
    select_choice "Edit existing"
    select_choice name
  end

  describe "Simplest Rails project" do
    it "allows adding a rails project" do
      add_prime_rails_project "someprime"
      expect(fsm.project.projects[0].name).to eq "someprime"
      add_prime_rails_project "otherprime"
      expect(fsm.project.projects[1].name).to eq "otherprime"
      #      whereami
    end
  end

  describe "Edit existing project" do
    it "Allows selecting an existing project" do
      add_prime_rails_project "someprime"
      edit_project "someprime"
      expect(fsm.state).to eq "edit_rails_project"
    end
    it "Allows toggling API mode for a rails project" do
      add_prime_rails_project "someprime"
      edit_project "someprime"
      select_choice "Toggle API mode"
      fsm.action
      expect(fsm.state).to eq "edit_rails_project"
    end
  end
  
  describe "Add linked postgres project" do
    it "allows creating linked postgres" do
      add_prime_rails_project "account"
      edit_project "account"
      allow(prompt).to receive(:ask).and_return "account-db"
      select_choice "Add postgres database"
      fsm.action
      expect(fsm.state).to eq "edit_rails_project"
    end
  end
end
