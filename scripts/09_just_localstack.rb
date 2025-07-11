#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("localstack") do
  localstack("eventstream") do |svc|
    svc.sns_sqs("do-the-things", %w[first-thing other-thing])
  end
end
