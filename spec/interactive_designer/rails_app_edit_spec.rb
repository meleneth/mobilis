# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

RSpec.describe "RailsAppEdit" do
  let(:metaproject) { build(:metaproject) }
  let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "somerails") }
  let(:fsm) do
    rails_project
    build(:fsm, project: metaproject)
  end
  let(:prompt) { fsm.prompt }
  let(:nav) { FSMNavigator.new fsm: fsm }

  describe "Add linked postgres project" do
    it "Event works to edit the project" do
      nav.select_choice "Edit existing"
      nav.select_choice "somerails"
      expect(fsm.state).to eq "rails_project_edit"
      expect(fsm.instance_variable_get(:@selected_rails_project)).to eq(rails_project)
    end
    it "allows creating linked postgres" do
      nav.select_choice "Edit existing"
      nav.select_choice "somerails"
      expect(fsm.state).to eq "rails_project_edit"
      allow(prompt).to receive(:ask).and_return "account-db"
      expect(rails_project).to receive(:add_linked_postgresql_instance).with("account-db")
      nav.select_choice "Add linked postgres database"
      fsm.action
      expect(fsm.state).to eq "rails_project_edit"
    end
  end

  describe "Toggle API Mode" do
    it "allows toggling of API mode" do
      nav.select_choice "Edit existing"
      expect(fsm.state).to eq "edit_project_menu"
      nav.select_choice "somerails"
      expect(metaproject.projects[0].options).to include(:api)
      expect(fsm.state).to eq "rails_project_edit"
      #  expect(rails_project).to receive(:toggle_rails_api_mode)
      nav.select_choice "Toggle API mode"
      expect(fsm.state).to eq "rails_project_toggle_api_mode"
      fsm.action
      expect(metaproject.projects[0].options).not_to include(:api)
    end
  end

  describe "toggle UUID primary keys" do
    it "allows toggle of UUID primary keys" do
      nav.select_choice "Edit existing"
      expect(fsm.state).to eq "edit_project_menu"
      nav.select_choice "somerails"
      expect(metaproject.projects[0].options).not_to include(:uuid)
      nav.select_choice "Toggle UUID primary keys mode"
      expect(fsm.state).to eq "rails_project_toggle_uuid_primary_keys_mode"
      fsm.action
      expect(metaproject.projects[0].options).to include(:api)
    end
  end
end
