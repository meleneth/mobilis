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

  def select_choice machine, name
    show_current_location
    puts "Selecting #{name}"

    choices = machine.choices
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
    puts "Machine in state: #{fsm.state}"
    puts fsm.choices
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
      select_choice fsm,"quit"
      expect(fsm.still_running?).to eq(false)
    end
  end

  describe "Add project" do
    it "Goes to the add project menu" do
      fsm.select_choice "Add project"
      expect(fsm.state).to eq("add_project_menu")
    end
  end

  describe "Add Kafka instance" do
    let(:metaproject) { build(:metaproject) }
    let(:kafka_project) { build(:kafka_instance, metaproject: metaproject, name: "somekafka") }
    let(:fsm_editor) { Mobilis::InteractiveDesigner::KafkaEdit.new kafka_project }

    before do
      allow(Mobilis::Project).to receive(:new).and_return metaproject
      allow(prompt).to receive(:ask).and_return "somekafka"
    end

    it "allows adding a Kafka project" do
      expect(metaproject).to receive(:add_kafka_instance).with("somekafka").and_return(kafka_project)

      select_choice fsm, "Add project"
      select_choice fsm,"Add kafka instance"
      fsm.action
      expect(fsm.state).to eq("main_menu")
    end
  end

  describe "Edit existing project" do
    let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "someprime") }
    let(:metaproject) { build(:metaproject) }
    let(:fsm) { rails_project ; build(:fsm, project: metaproject) }

    it "Allows selecting an existing project" do
      rails_project
      select_choice fsm, "Edit existing"
      select_choice fsm, "someprime"
      expect(fsm.state).to eq "rails_project_edit"
    end
  end
end
