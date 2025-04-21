# frozen_string_literal: true

require "mobilis"

system = Mobilis::System.new

rails = Mobilis::Node::Rails.new("user")
user_db = Mobilis::Node::PostgreSQL.new("user-db")

rails.primary_database = user_db

system << rails
system << user_db

manifest = Mobilis::Manifest.new(system)

manifest.materialize
