#!/usr/bin/env ruby

require "mobilis"

system = Mobilis::System.new("generate")

rails = Mobilis::Node::Rails.new("user-service")
user_db = Mobilis::Node::PostgreSQL.new("user-db")

rails.primary_database = user_db

rails.api_mode = true

rails.add_rails_model("user") do
  string "name"
  integer "score"
end

system << rails
system << user_db

manifest = Mobilis::Manifest.new(system)

manifest.materialize
