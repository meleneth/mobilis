# frozen_string_literal: true

RSpec.describe Mobilis::InteractiveDesigner::KafkaEdit do
  let(:metaproject) { build(:metaproject) }
  let(:kafka_instance) { build(:kafka_instance, metaproject: metaproject) }

  let(:fsm) do
    kafka_instance
    build(:fsm, project: metaproject)
  end
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

  describe "can finish" do
    it "changes still_running? to be false" do
      expect(fsm.still_running?).to eq(true)
      select_choice "quit"
      expect(fsm.state).to eq("quit")
      expect(fsm.still_running?).to eq(false)
    end
  end

  describe "can edit kafka" do
    it "gets to edit_screen" do
      select_choice "[m] Edit existing project"
      expect(fsm.state).to eq("edit_project_menu")
    end
  end
end
