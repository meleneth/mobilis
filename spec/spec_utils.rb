class FSMNavigator
  attr_accessor :fsm

  def initialize(fsm:)
    @fsm = fsm
  end
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
end