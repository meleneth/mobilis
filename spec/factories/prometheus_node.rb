# frozen_string_literal: true

FactoryBot.define do
  factory :prometheus_node, class: Mobilis::Node::Prometheus do
    name { "prometheus" }
    transient { id { nil } }

    initialize_with { new(name, id: id) }
  end
end
