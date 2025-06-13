#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  rails("user-service", primary_database: postgres("user-db")) do |svc|
    svc.add_rails_model("user") do |m|
      m.string "name"
      m.integer "score"
    end
  end
end
