#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

blue_styles = [:blue]
green_styles = [:green]
yellow_styles = [:yellow]
red_styles = [:red]

gram = JobesWar::Diagram.new
value = JobesWar::Node::Value.new("A very long Value", parent: gram, styles: blue_styles)
outer_box = JobesWar::Node::Box.new(label: "look here", styles: green_styles, label_styles: yellow_styles)
outer_box << value
gram << outer_box
print gram.render

print "\n"

# gram = JobesWar::Diagram.new(fullwidth: true)
value = JobesWar::Node::Value.new("A Value", parent: gram, styles: blue_styles)
box = JobesWar::Node::Box.new(label: "look here", styles: yellow_styles, label_styles: red_styles)
box << value

outer_box << box

print gram.render

print "\n"
