# frozen_string_literal: true

module Mobilis
  class SceneFSM < Mel::SceneFSM
    def select_choice name
      fsm_choices = choices
      if fsm_choices
        fsm_choices.each do |choice|
          return choice[:value].call if choice[:name].include? name
        end
        raise "Choice not found"
      end
      puts "Choices didn't exist"
    end
  end
end
