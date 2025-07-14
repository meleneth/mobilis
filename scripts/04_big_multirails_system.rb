#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  rails("user-service", primary_database: postgres("user-db"), api: true) do |svc|
    svc.use_api!
    svc.add_rails_model("user") do |m|
      m.string "name"
      m.string "title"
      m.integer "account_id"
    end
  end

  rails("account-service", primary_database: postgres("account-db"), api: true) do |svc|
    svc.use_api!
    svc.add_rails_model("account") { |m| m.string "name" }
    svc.add_rails_model("group")   { |m| m.string "name" }
    svc.add_rails_model("account_group") do |m|
      m.references "account"
      m.references "group"
    end
  end

  rails("article-service", primary_database: postgres("article-db"), api: true) do |svc|
    svc.use_api!
    svc.add_rails_model("article") do |m|
      m.string "title"
      m.text "body"
      m.integer "user_id"
    end
  end

  connect from: "article-service", to: "user-service"
  connect from: "article-service", to: "account-service"

  # head off circular health check issue
  connect from: "user-service", to: "account-service", force_skip_health_checks: true
end
