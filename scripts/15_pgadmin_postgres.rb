#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("generate") do
  database = postgres("user-db")

  pgadmin("pgadmin", databases: [database])
end
