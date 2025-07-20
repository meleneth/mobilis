#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  rails("somewebsite", primary_database: postgres("user-db")) do |svc|
    svc.use_rspec!
    svc.use_haml!
    svc.use_tailwind!
    svc.use_uuid_primary_keys!
    svc.add_rails_model("user") do |m|
      m.string "name"
      m.integer "score"
    end
  end
end
