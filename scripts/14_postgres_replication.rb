#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("generate") do
  primary = postgres("primary-db")

  postgres("replica-db") do |db|
    db.replicate_from(primary)
  end
end
