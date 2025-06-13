#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("otel-generate") do
  grafana("grafana")
  jaeger("jaeger")
  otel_collector("otel-collector")
  prometheus("prometheus")

  connect from: "grafana",        to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus",     to: "otel-collector"
end
