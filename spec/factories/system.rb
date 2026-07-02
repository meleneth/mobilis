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

    trait :with_pgadmin_and_postgres do
      after(:build) do |system|
        postgres_node = build(:postgres_node, name: "userdb")
        pgadmin_node = build(:pgadmin_node, name: "pgadmin")
        pgadmin_node.add_database(postgres_node)

        system << postgres_node
        system << pgadmin_node
      end
    end

    trait :with_mysql do
      after(:build) do |system|
        mysql_node = build(:mysql_node, name: "userdb")
        system << mysql_node
      end
    end

    trait :with_s3_storage do
      after(:build) do |system|
        s3_node = build(:s3_storage_node, name: "assets", buckets: ["uploads", "exports"])
        system << s3_node
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

    trait :with_rails_and_mysql do
      transient do
        rails_name { "user" }
        db_name    { "userdb" }
      end

      after(:build) do |system, evaluator|
        mysql = build(:mysql_node, name: evaluator.db_name)
        rails = build(:rails_node, name: evaluator.rails_name, primary_database: mysql)

        system << mysql
        system << rails
      end
    end

    trait :with_otel do
      after(:build) do |system|
        collector_node = build(:otel_collector_node, name: "otel-collector")
        prometheus_node = build(:prometheus_node, name: "prometheus")
        jaeger_node = build(:jaeger_node, name: "jaeger")
        grafana_node = build(:grafana_node, name: "grafana")
        loki_node = build(:loki_node, name: "loki")
        alloy_node = build(:alloy_node, name: "alloy", loki: loki_node)

        grafana_node.has_extra_depends_on(prometheus_node)
        grafana_node.has_extra_depends_on(loki_node)
        collector_node.has_extra_depends_on(jaeger_node)
        prometheus_node.has_extra_depends_on(collector_node)

        system << collector_node
        system << prometheus_node
        system << jaeger_node
        system << grafana_node
        system << loki_node
        system << alloy_node
      end
    end

    trait :with_observable_rails_and_databases do
      after(:build) do |system|
        collector_node = build(:otel_collector_node, name: "otel-collector")
        prometheus_node = build(:prometheus_node, name: "prometheus")
        jaeger_node = build(:jaeger_node, name: "jaeger")
        grafana_node = build(:grafana_node, name: "grafana")
        loki_node = build(:loki_node, name: "loki")
        alloy_node = build(:alloy_node, name: "alloy", loki: loki_node)
        postgres_node = build(:postgres_node, name: "userdb")
        mysql_node = build(:mysql_node, name: "legacydb")
        rails_node = build(:rails_node, name: "user-service", primary_database: postgres_node)

        rails_node.add_rails_model("user") do |model|
          model.filterable :id, :account_id, :email
        end

        grafana_node.has_extra_depends_on(prometheus_node)
        grafana_node.has_extra_depends_on(loki_node)
        collector_node.has_extra_depends_on(jaeger_node)
        prometheus_node.has_extra_depends_on(collector_node)

        system << collector_node
        system << prometheus_node
        system << jaeger_node
        system << grafana_node
        system << loki_node
        system << alloy_node
        system << postgres_node
        system << mysql_node
        system << rails_node
      end
    end

    trait :with_observable_s3_storage do
      after(:build) do |system|
        prometheus_node = build(:prometheus_node, name: "prometheus")
        grafana_node = build(:grafana_node, name: "grafana")
        loki_node = build(:loki_node, name: "loki")
        alloy_node = build(:alloy_node, name: "alloy", loki: loki_node)
        s3_node = build(:s3_storage_node, name: "assets", buckets: ["uploads"])

        grafana_node.has_extra_depends_on(prometheus_node)
        grafana_node.has_extra_depends_on(loki_node)
        s3_node.has_extra_depends_on(alloy_node)
        s3_node.has_extra_depends_on(prometheus_node)

        system << prometheus_node
        system << grafana_node
        system << loki_node
        system << alloy_node
        system << s3_node
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

        rails_two.has_extra_depends_on(rails_one)

        system << pg_one
        system << rails_one
        system << pg_two
        system << rails_two
      end
    end
  end
end
