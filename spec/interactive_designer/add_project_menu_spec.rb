# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

# > reload all code
#   [m] Add project
#   [m] Edit existing project
#   [m] Show configuration
#   quit

RSpec.describe 'AddProjectMenu' do
  let(:fsm) { Mobilis::InteractiveDesigner::MainMenu.new }
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
    puts "Machine in state: #{fsm.state}"
    puts fsm.choices
  end

  def edit_project name
    select_choice "Edit existing"
    select_choice name
  end

  describe "Simplest Rails project" do
    let(:metaproject) { build(:metaproject) }
    let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "someprime") }

    before do
      allow(Mobilis::Project).to receive(:new).and_return metaproject
    end

    it "allows adding a rails project" do
      expect(prompt).to receive(:ask).and_return "someprime"
      expect(metaproject).to receive(:add_prime_stack_rails_project).with("someprime").and_return(rails_project)
      expect(fsm.state).to eq("main_menu")
      fsm.select_choice "Add project"
      expect(fsm.state).to eq("add_project_menu")
      fsm.select_choice "Add prime stack"
      fsm.action
      expect(fsm.state).to eq("rails_project_edit")
    end
  end

  describe "Add rack3 instance" do
    let(:metaproject) { build(:metaproject) }
    let(:rack_project) { build(:rack_project, metaproject: metaproject, name: "somerack") }
    let(:fsm_editor) { Mobilis::InteractiveDesigner::Rack.new rack_project }

    before do
      allow(Mobilis::Project).to receive(:new).and_return metaproject
      allow(prompt).to receive(:ask).and_return "somerack"
    end

    it "allows adding a rack project" do
      expect(metaproject).to receive(:add_rack_project).with("somerack").and_return(rack_project)

      select_choice "Add project"
      select_choice "Add rack3 project"
      fsm.action
      expect(fsm.state).to eq("main_menu")
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

      select_choice "Add project"
      select_choice "Add kafka instance"
      fsm.action
      expect(fsm.state).to eq("main_menu")
    end
  end

  describe "Edit existing project" do
    let(:metaproject) { build(:metaproject) }
    let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "somerails") }
    let(:fsm) do
      rails_project
      build(:fsm, project: metaproject)
    end
    let(:prompt) { fsm.prompt }
    it "Allows selecting an existing project" do
      select_choice "Edit existing project"
      select_choice "somerails"
      expect(fsm.state).to eq "rails_project_edit"
    end
  end
end
