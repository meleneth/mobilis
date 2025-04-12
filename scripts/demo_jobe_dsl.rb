#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

diagram = JobesWar.draw do
  box "look here", styles: [:green], label_styles: [:yellow] do
    value "A very long Value", styles: [:blue]

    box "look here", styles: [:yellow], label_styles: [:red] do
      value "A Value", styles: [:blue]

      tic_tac do
        row do
          value "A", styles: [:red]
          value "B", styles: [:green]
        end
        row do
          value "C", styles: [:blue]
          value "D", styles: [:yellow]
        end
      end
    end
  end
end

puts diagram.render
