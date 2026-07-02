# frozen_string_literal: true

FactoryBot.define do
  factory :pgadmin_node, class: Mobilis::Node::Pgadmin do
    name { "pgadmin" }
    transient { id { nil } }

    initialize_with { new(name, id: id) }
  end
end
