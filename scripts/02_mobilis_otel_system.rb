#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("otel-generate") do
  grafana("grafana")
  jaeger("jaeger")
  logs = loki("loki")
  otel_collector("otel-collector")
  prometheus("prometheus")
  promtail("promtail", loki: logs)

  connect from: "grafana",        to: "loki"
  connect from: "grafana",        to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus",     to: "otel-collector"
end
