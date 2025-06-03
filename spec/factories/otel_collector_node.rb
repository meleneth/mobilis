# frozen_string_literal: true

FactoryBot.define do
  factory :otel_collector_node, class: Mobilis::Node::OtelCollector do
    name { "otel-collector" }
    transient { id { nil } }

    initialize_with { new(name, id: id) }
  end
end
