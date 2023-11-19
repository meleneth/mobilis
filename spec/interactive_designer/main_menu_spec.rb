# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

# > reload all code
#   [m] Add project
#   [m] Edit existing project
#   [m] Show configuration
#   quit

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

  describe "Quit" do
    it "is running by default" do
      expect(fsm.still_running?).to eq(true)
    end
    it "stops running" do
      select_choice "quit"
      expect(fsm.still_running?).to eq(false)
    end
  end

  describe "Simplest Rails project" do
    let(:metaproject) { build(:metaproject) }
    let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "someprime") }
    let(:fsm_editor) { Mobilis::InteractiveDesigner::RailsAppEdit.new rails_project }

    before do
      allow(Mobilis::Project).to receive(:new).and_return metaproject
      allow(fsm).to receive(:editor_machine_for).with(rails_project).and_return fsm_editor
      allow(prompt).to receive(:ask).and_return "someprime"
    end

    it "allows adding a rails project" do
      expect(metaproject).to receive(:add_prime_stack_rails_project).with("someprime").and_return(rails_project)
      expect(fsm).to receive(:visit_submachine).with fsm_editor

      select_choice "Add project"
      select_choice "Add prime stack"
      fsm.action
      expect(fsm.state).to eq("main_menu")
    end
  end

  describe "Add Kafka instance" do
    let(:metaproject) { build(:metaproject) }
    let(:kafka_project) { build(:kafka_instance, metaproject: metaproject, name: "somekafka") }
    let(:fsm_editor) { Mobilis::InteractiveDesigner::KafkaInstanceEdit.new kafka_project }

    before do
      allow(Mobilis::Project).to receive(:new).and_return metaproject
      allow(fsm).to receive(:editor_machine_for).with(kafka_project).and_return fsm_editor
      allow(prompt).to receive(:ask).and_return "somekafka"
    end

    it "allows adding a Kafka project" do
      expect(metaproject).to receive(:add_kafka_instance).with("somekafka").and_return(kafka_project)
      expect(fsm).to receive(:visit_submachine).with fsm_editor

      select_choice "Add project"
      select_choice "Add Kafka instance"
      fsm.action
      expect(fsm.state).to eq("main_menu")
    end
  end

  describe "Edit existing project" do
    xit "Allows selecting an existing project" do
      add_prime_rails_project "someprime"
      edit_project "someprime"
      expect(fsm.state).to eq "edit_rails_project"
    end
  end
end
