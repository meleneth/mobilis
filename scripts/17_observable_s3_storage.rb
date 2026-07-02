#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("observable-s3") do
  logs = loki("loki")
  prometheus("prometheus")
  grafana("grafana")
  alloy("alloy", loki: logs)
  s3("assets", buckets: ["uploads", "exports"])

  connect from: "assets", to: "alloy"
  connect from: "assets", to: "prometheus"
  connect from: "grafana", to: "loki"
  connect from: "grafana", to: "prometheus"
end
