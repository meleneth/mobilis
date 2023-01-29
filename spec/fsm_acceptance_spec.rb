# frozen_string_literal: true

require 'mobilis/interactive_designer'

RSpec.describe "FSM Acceptance" do
  let(:fsm) do
    id = Mobilis::InteractiveDesigner.new
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
      select_choice 'Add project'
      select_choice 'Add prime stack'
      allow(prompt).to receive(:ask).and_return name
      fsm.action
      select_choice 'return to Main Menu'
  end

  describe "Simplest Rails project" do
    it "allows adding a rails project" do
      add_prime_rails_project 'someprime'
      expect(fsm.project.projects[0].name).to eq 'someprime'
      add_prime_rails_project 'otherprime'
      expect(fsm.project.projects[1].name).to eq 'otherprime'
#      whereami
    end
  end
end
