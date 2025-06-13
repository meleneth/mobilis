#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  rails("user-service", primary_database: postgres("user-db")) do |svc|
    svc.add_rails_model("user") do |m|
      m.string  "name"
      m.integer "score"
    end
  end

  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  prometheus("prometheus")

  connect from: "user-service", to: "otel-collector"
  connect from: "grafana",       to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus",    to: "otel-collector"
end
