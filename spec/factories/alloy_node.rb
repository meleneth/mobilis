# frozen_string_literal: true

FactoryBot.define do
  factory :alloy_node, class: "Mobilis::Node::Alloy" do
    transient { name { "alloy" } }

    initialize_with { new(name) }
  end
end
