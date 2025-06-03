# frozen_string_literal: true

FactoryBot.define do
  factory :grafana_node, class: Mobilis::Node::Grafana do
    name { "grafana" }
    transient { id { nil } }

    initialize_with { new(name, id: id) }
  end
end
