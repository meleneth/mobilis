# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

RSpec.describe Mobilis::InteractiveDesigner::MainMenu do
  let(:fsm) { Mobilis::InteractiveDesigner::MainMenu.new }

  let(:prompt) { fsm.prompt }

  def select_choice name
    fsm.choices.each do |choice|
      return choice[:value].call if choice[:name].include? name
    end
    raise "choice #{name} not seen"
  end

  def whereami
    expect(fsm.choices).to eq([])
  end

  def add_prime_rails_project name
  end

  def edit_project name
    select_choice "Edit existing"
    select_choice name
  end

  describe "Simplest Rails project" do
    it "allows adding a rails project" do
      select_choice "Add project"
      allow(prompt).to receive(:ask).and_return "someprime"
      select_choice "Add prime stack"
      select_choice "return to Main Menu"
      add_prime_rails_project "someprime"
    end
  end

  describe "Edit existing project" do
    it "Allows selecting an existing project" do
      add_prime_rails_project "someprime"
      edit_project "someprime"
      expect(fsm.state).to eq "edit_rails_project"
    end
  end
end
