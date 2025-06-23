#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  rails("iam-service", primary_database: postgres("iam-db")) do |svc|
    svc.install_graphql!
    svc.run_command("bundle exec rails db:migrate", "apply schema changes")

    svc.add_rails_model("account") do |m|
      m.string "name"
    end

    svc.run_command("bundle exec rails g graphql:object Account name:string", "create Account GraphQL model")

    svc.add_rails_model("group") do |m|
      m.string "name"
    end

    svc.run_command("bundle exec rails g graphql:object Group name:string", "create Group GraphQL model")

    svc.add_rails_model("account_group") do |m|
      m.references "account", cardinality: :has_one
      m.references "group", cardinality: :has_one
    end

    svc.add_rails_model("user") do |m|
      m.string "name"
      m.string "email"
      m.references "account", cardinality: :has_one
    end

    svc.run_command("bundle exec rails g graphql:object User name:string account:Account", "create User GraphQL model")

    svc.add_rails_model("account_membership") do |m|
      m.references "account", cardinality: :has_many
      m.references "user", cardinality: :has_one
      m.string "role"
    end

    svc.add_rails_model("user_session") do |m|
      m.references "user", cardinality: :has_one
      m.datetime "started_at"
      m.string "ip_address"
    end

    svc.write_file("lib/tasks/trace.rake", <<~HERE)
      namespace :demo do
        task :trace => :environment do
          Instrumentation.trace("demo.iam.seed") do
            account = Account.create!(name: "Acme Corp")
            group   = Group.create!(name: "Admins")
            user    = User.create!(name: "Tracey", email: "t@example.com", account: account)

            AccountGroup.create!(account: account, group: group)
            AccountMembership.create!(account: account, user: user, role: "admin")

            UserSession.create!(user: user, started_at: Time.now, ip_address: "127.0.0.1")
          end
        end
      end
    HERE
  end
end
