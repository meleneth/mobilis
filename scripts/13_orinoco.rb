#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  rails("orinoco", primary_database: postgres("orinoco-db")) do |svc|
    svc.use_rspec!
    svc.use_tailwind!
    svc.use_uuid_primary_keys!
  end

  goaws("goaws")

  connect from: "orinoco", to: "goaws"
end
