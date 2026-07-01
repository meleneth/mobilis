#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("parent_account_id") do
  # Infra

  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  logs = loki("loki")
  prometheus("prometheus")
  promtail("promtail", loki: logs)

  connect from: "grafana", to: "loki"
  connect from: "grafana", to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus", to: "otel-collector"

  # Services

  rails("group-service", primary_database: postgres("group-db"), api: true) do |svc|
    svc.install_graphql!
    svc.use_rspec!

    svc.write_file("app/models/group.rb", <<~GROUPMODEL)
      # frozen_string_literal: true

      class Group < ApplicationRecord
      end
    GROUPMODEL

    svc.write_file("app/models/group_user.rb", <<~GROUPUSERMODEL)
      # frozen_string_literal: true

      class GroupUser < ApplicationRecord
      end
    GROUPUSERMODEL

    svc.write_file("db/migrate/20250714003611_create_groups.rb", <<~GROUPS)
      # frozen_string_literal: true
      class CreateUsers < ActiveRecord::Migration[8.0]
        def change
          create_table :groups, id: :uuid do |t|
            t.uuid :account_id, index: true
            t.string :name
            t.timestamps
          end
        end
      end
    GROUPS

    svc.write_file("db/migrate/20250714003612_create_group_users.rb", <<~GROUPUSERS)
      # frozen_string_literal: true
      class CreateUsers < ActiveRecord::Migration[8.0]
        def change
          create_table :group_users, id: :uuid do |t|
            t.uuid :group_id, index: true
            t.uuid :user_id, index: true
            t.timestamps
          end
        end
      end
    GROUPUSERS

  end

  redis("groupcache")
  connect from: "group-service", to: "groupcache"

  # OTEL wiring
  connect from: "group-service", to: "otel-collector"
end
