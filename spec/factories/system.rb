# frozen_string_literal: true

FactoryBot.define do
  factory :system, class: "Mobilis::System" do
    initialize_with { new(meta_project_name) }

    # Empty by default — use traits to populate nodes
    transient do
      nodes { [] }
      meta_project_name { "generate" }
    end

    after(:build) do |system, evaluator|
      evaluator.nodes.each do |node|
        system << node
      end
    end

    trait :with_postgres do
      after(:build) do |system|
        postgres_node = build(:postgres_node, name: "userdb")
        system << postgres_node
      end
    end

    trait :with_rails do
      after(:build) do |system|
        rails_node = build(:rails_node, name: "user")
        system << rails_node
      end
    end

    trait :with_rails_and_postgres do
      transient do
        rails_name { "user" }
        db_name    { "userdb" }
      end

      after(:build) do |system, evaluator|
        pg = build(:postgres_node, name: evaluator.db_name)
        rails = build(:rails_node, name: evaluator.rails_name, primary_database: pg)

        system << pg
        system << rails
      end
    end
  end
end
