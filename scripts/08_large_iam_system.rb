#!/usr/bin/env ruby

require "mobilis"

# FIXME: TODO currently broken, uuid support doesn't exist

Mobilis::DSL.generate("parent_account_id") do
  # Infra
  redis("authcache")

  localstack("eventstream") do |svc|
    svc.sns_sqs("capability-changes", ["capability-changes"])
    svc.sns_sqs("group-membership-changes", ["group-membership-changes"])
    svc.sns_sqs("account-structure-changes", ["account-structure-changes"])
  end

  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  prometheus("prometheus")

  connect from: "grafana", to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus", to: "otel-collector"

  # Services

  rails("user", primary_database: postgres("user-db"), api: true) do |svc|
    svc.install_graphql!

    svc.add_rails_model("user") do |m|
      m.uuid :id, primary_key: true
      m.string :email
      m.string :username
      m.string :first_name
      m.string :last_name
      m.string :middle_name
      m.string :phone_number
      m.string :alt_phone
      m.string :slack_id
      m.string :avatar_url
      m.string :linkedin
      m.string :github
      m.string :twitter
      m.string :tshirt_size
      m.string :pronouns
      m.string :timezone
      m.timestamps
    end
  end

  rails("account", primary_database: postgres("account-db"), api: true) do |svc|
    svc.install_graphql!

    svc.add_rails_model("account") do |m|
      m.uuid :id, primary_key: true
      m.string :name
      m.uuid :parent_id
      m.timestamps
    end
  end

  rails("authorization", primary_database: postgres("authz-db"), api: true) do |svc|
    svc.install_graphql!

    svc.add_rails_model("capability") do |m|
      m.uuid :id, primary_key: true
      m.uuid :subject_id
      m.uuid :account_id
      m.string :capability
      m.timestamps
    end
  end

  connect from: "authorization", to: "authcache"

  rails("organization", primary_database: postgres("organization-db"), api: true) do |svc|
    svc.install_graphql!

    svc.add_rails_model("organization") do |m|
      m.uuid :id, primary_key: true
      m.string :name
      m.uuid :subject_id
      m.uuid :account_id
      m.string :capability
      m.timestamps
    end

    svc.add_rails_model("organization_accounts") do |m|
      m.uuid :id, primary_key: true
      m.uuid :account_id
    end
  end

  rails("permissions") do |svc|
    svc.install_graphql!
  end

  # OTEL wiring
  connect from: "user", to: "otel-collector"
  connect from: "account", to: "otel-collector"
  connect from: "authorization", to: "otel-collector"
  connect from: "permissions", to: "otel-collector"
end
