# frozen_string_literal: true

FactoryBot.define do
  factory :rack_node, class: Mobilis::Node::Rack do
    name { "rackapp" }
    instances { 1 }
    transient { id { nil } }

    initialize_with { new(name, instances: instances, id: id) }
  end
end
