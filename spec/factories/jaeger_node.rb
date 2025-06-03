# frozen_string_literal: true

FactoryBot.define do
  factory :jaeger_node, class: Mobilis::Node::Jaeger do
    name { "jaeger" }
    transient { id { nil } }

    initialize_with { new(name, id: id) }
  end
end
