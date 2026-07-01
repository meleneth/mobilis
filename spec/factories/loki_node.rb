# frozen_string_literal: true

FactoryBot.define do
  factory :loki_node, class: "Mobilis::Node::Loki" do
    transient do
      name { "loki" }
    end

    initialize_with { new(name) }
  end
end
