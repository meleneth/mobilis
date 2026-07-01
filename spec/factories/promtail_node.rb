# frozen_string_literal: true

FactoryBot.define do
  factory :promtail_node, class: "Mobilis::Node::Promtail" do
    transient do
      name { "promtail" }
      loki { nil }
    end

    initialize_with { new(name) }

    after(:build) do |node, evaluator|
      node.loki = evaluator.loki if evaluator.loki
    end
  end
end
