#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("parent_account_id") do
  # Infra
  redis("authcache")

  goaws("eventstream") do |svc|
    svc.sns_sqs("capability-changes", ["capability-changes"])
    svc.sns_sqs("group-membership-changes", ["group-membership-changes"])
    svc.sns_sqs("account-structure-changes", ["account-structure-changes"])
  end

  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  logs = loki("loki")
  prometheus("prometheus")
  alloy("alloy", loki: logs)

  connect from: "grafana", to: "loki"
  connect from: "grafana", to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus", to: "otel-collector"

  # Services

  rails("user-service", primary_database: postgres("user-db"), api: true) do |svc|
    svc.install_graphql!
    svc.use_rspec!
    svc.add_rails_model("user") do |m|
      m.existing!
      m.filterable :id, :account_id, :email, :username
    end

    svc.write_file("app/models/user.rb", <<~USERMODEL)
      # frozen_string_literal: true

      class User < ApplicationRecord
      end
    USERMODEL

    svc.write_file("db/migrate/20250714003610_create_users.rb", <<~USERS)
      # frozen_string_literal: true
      class CreateUsers < ActiveRecord::Migration[8.0]
        def change
          create_table :users, id: :uuid do |t|
            t.uuid :account_id, index: true
            t.string :email
            t.string :username
            t.string :first_name
            t.string :last_name
            t.string :middle_name
            t.string :phone_number
            t.string :alt_phone
            t.string :slack_id
            t.string :avatar_url
            t.string :linkedin
            t.string :github
            t.string :twitter
            t.string :tshirt_size
            t.string :pronouns
            t.string :timezone
            t.timestamps
          end
        end
      end
    USERS
  end

  rails("account-service", primary_database: postgres("account-db"), api: true) do |svc|
    svc.install_graphql!
    svc.use_rspec!
    svc.add_rails_model("account") do |m|
      m.existing!
      m.filterable :id, :parent_account_id, :name
    end

    svc.write_file("db/migrate/20250714003609_create_accounts.rb", <<~ACCOUNTS)
      # frozen_string_literal: true
      class CreateAccounts < ActiveRecord::Migration[8.0]
        def change
          create_table :accounts, id: :uuid do |t|
            t.string :name
            t.uuid :parent_account_id, index: true

            t.timestamps
          end

          add_foreign_key :accounts, :accounts, column: :parent_account_id
        end
      end
    ACCOUNTS

    svc.write_file("app/models/account.rb", <<~ACCOUNTMODEL)
      # frozen_string_literal: true
      # app/models/account.rb

      class Account < ApplicationRecord
        belongs_to :parent_account, class_name: "Account", optional: true
        has_many :child_accounts, class_name: "Account", foreign_key: :parent_account_id, dependent: :nullify
        before_validation :assign_default_name, on: :create

        private

        def assign_default_name
          if name.blank?
            self.id ||= SecureRandom.uuid
            self.name = "Account \#{id}".truncate(36)
          end
        end
      end
    ACCOUNTMODEL
  end

  rails("authorization-service", primary_database: postgres("authz-db"), api: true) do |svc|
    svc.install_graphql!
    svc.use_rspec!
    svc.add_rails_model("capability") do |m|
      m.existing!
      m.filterable :id, :subject_id, :account_id, :permission
    end

    svc.write_file("db/migrate/20250714003611_create_capabilities.rb", <<~CAPABILITIES)
      # frozen_string_literal: true
      class CreateCapabilities < ActiveRecord::Migration[8.0]
        def change
          create_table :capabilities, id: :uuid do |t|
            t.uuid :subject_id, index: true
            t.uuid :account_id, index: true
            t.string :permission
            t.timestamps
          end
        end
      end
    CAPABILITIES

    svc.write_file("app/models/capability.rb", <<~CAPABILITYMODEL)
      # frozen_string_literal: true

      class Capability < ApplicationRecord
      end
    CAPABILITYMODEL
  end

  connect from: "authorization-service", to: "authcache"
  connect from: "authorization-service", to: "eventstream"

  rails("organization-service", primary_database: postgres("organization-db"), api: true) do |svc|
    svc.install_graphql!
  end

  rails("user-management-service") do |svc|
    svc.install_graphql!
    svc.use_tailwind!
    svc.use_rspec!
    svc.write_file("scripts/setup.sh", <<~SETUP)
      #!/bin/bash
      bundle add activeresource --require active_resource
    SETUP

    svc.write_file("scripts/create_user.rb", <<~USERMODEL)
      # frozen_string_literal: true

      # app/models/user.rb
      class User < ActiveResource::Base
        self.site = ENV.fetch("USER_API_BASE_URL") # e.g., http://user-service:3000/
        self.format = :json

        # Optional: if the resource uses UUIDs instead of integers
        self.primary_key = "id"

        # Optional: if user-service uses a different collection path
        self.collection_name = "users"

        # Optional: handle nested resources, errors, etc.
      end
    USERMODEL

    svc.write_file("scripts/create_user.rb", <<~CREATEUSER)
      User.create(name: "bleh")
    CREATEUSER
  end

  # OTEL wiring
  connect from: "user-service", to: "otel-collector"
  connect from: "account-service", to: "otel-collector"
  connect from: "authorization-service", to: "otel-collector"
  connect from: "user-management-service", to: "otel-collector"

  # user-management wiring

  connect from: "user-management-service", to: "user-service"
  connect from: "user-management-service", to: "account-service"
  connect from: "user-management-service", to: "authorization-service"
  connect from: "user-management-service", to: "organization-service"
  connect from: "user-management-service", to: "eventstream"
end
