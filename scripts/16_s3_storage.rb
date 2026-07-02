#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("generate") do
  s3("assets", buckets: ["uploads", "exports"])
end
