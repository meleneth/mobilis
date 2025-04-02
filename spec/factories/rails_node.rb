# frozen_string_literal: true

FactoryBot.define do
  factory :rails_node, class: Mobilis::Node::Rails do
    name { "rails" }
    transient { id { nil } }

    initialize_with { new(name, id: id) }

    trait :with_postgres do
      transient do
        postgres_node { build(:postgres_node) }
      end

      after(:build) do |rails_node, evaluator|
        rails_node.primary_database = evaluator.postgres_node
      end
    end
  end
end
