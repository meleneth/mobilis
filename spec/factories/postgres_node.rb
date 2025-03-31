# frozen_string_literal: true

FactoryBot.define do
  factory :postgres_node, class: Mobilis::Nodes::PostgreSQL do
    name { "pg" }
    transient { id { nil } }

    initialize_with { new(name, id: id) }
  end
end
