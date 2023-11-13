# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

RSpec.describe Mobilis::InteractiveDesigner::RailsAppEdit do
  let(:metaproject) { build(:metaproject) }
  let(:rails_project) { build(:rails_prime, metaproject: metaproject) }

  let(:fsm) { Mobilis::InteractiveDesigner::RailsAppEdit.new rails_project }
  let(:prompt) { fsm.prompt }

  def select_choice name
    fsm.choices.each do |choice|
      return choice[:value].call if choice[:name].include? name
    end
    raise "Choice not found"
  end

  def whereami
    expect(fsm.choices).to eq([])
  end

  describe "can finish" do
    it "changes still_running? to be false" do
      expect(fsm.still_running?).to eq(true)
      select_choice "return to Main Menu"
      expect(fsm.still_running?).to eq(false)
    end
  end

  describe "Add linked postgres project" do
    it "allows creating linked postgres" do
      expect(fsm.state).to eq "rails_app_edit_screen"
      allow(prompt).to receive(:ask).and_return "account-db"
      expect(rails_project).to receive(:add_linked_postgresql_instance).with("account-db")
      select_choice "Add linked postgres database"
      fsm.action
      expect(fsm.state).to eq "rails_app_edit_screen"
    end
  end
end
