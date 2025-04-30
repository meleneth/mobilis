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

    trait :with_two_rails_and_postgres do
      transient do
        rails_one_name { "user" }
        rails_two_name { "account" }
        db_one_name    { "userdb" }
        db_two_name    { "accountdb" }
      end

      after(:build) do |system, evaluator|
        pg_one = build(:postgres_node, name: evaluator.db_one_name)
        rails_one = build(:rails_node, name: evaluator.rails_one_name, primary_database: pg_one)

        pg_two = build(:postgres_node, name: evaluator.db_two_name)
        rails_two = build(:rails_node, name: evaluator.rails_two_name, primary_database: pg_two)

        rails_two.extra_depends_on << rails_one

        system << pg_one
        system << rails_one
        system << pg_two
        system << rails_two
      end
    end
  end
end
