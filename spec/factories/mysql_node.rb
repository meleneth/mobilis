# frozen_string_literal: true

FactoryBot.define do
  factory :mysql_node, class: Mobilis::Node::MySQL do
    name { "mysql" }

    initialize_with { new(name) }
  end
end
