#!/usr/bin/env ruby

require "mobilis"

system = Mobilis::System.new("generate")

user = Mobilis::Node::Rails.new("user-service")
user_db = Mobilis::Node::PostgreSQL.new("user-db")

account = Mobilis::Node::Rails.new("account-service")
account_db = Mobilis::Node::PostgreSQL.new("account-db")

article = Mobilis::Node::Rails.new("article-service")
article_db = Mobilis::Node::PostgreSQL.new("article-db")

user.primary_database = user_db
account.primary_database = account_db
article.primary_database = article_db

account.add_rails_model("account") do
  string "name"
end

account.add_rails_model("group") do
  string "name"
end

account.add_rails_model("account_group") do
  references "account"
  references "group"
end

user.add_rails_model("user") do
  string "name"
  string "title"
  integer "account_id"
end

article.add_rails_model("article") do
  string "title"
  text "body"
  integer "user_id"
end

system << user
system << user_db
system << account
system << account_db
system << article
system << article_db

manifest = Mobilis::Manifest.new(system)

manifest.materialize
