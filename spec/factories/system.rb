# frozen_string_literal: true

FactoryBot.define do
  factory :system, class: "Mobilis::System" do
    initialize_with { new }

    # Empty by default — use traits to populate nodes
    transient do
      nodes { [] }
    end

    after(:build) do |system, evaluator|
      evaluator.nodes.each do |node|
        system << node
      end
    end

    trait :with_rails_and_postgres do
      transient do
        rails_name { "myapp" }
        db_name    { "pg_main" }
      end

      after(:build) do |system, evaluator|
        pg = build(:postgres_node, name: evaluator.db_name)
        rails = build(:rails_node, name: evaluator.rails_name, primary_database: pg)

        system.add_node(pg)
        system.add_node(rails)
      end
    end
  end
end
