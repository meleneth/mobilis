#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("otel-generate") do
  grafana("grafana")
  jaeger("jaeger")
  otel_collector("otel-collector")
  prometheus("prometheus")

  flask("flasker") do |svc|
    svc.add_script("some_script.sh", <<~SHELL)
      #!/bin/bash
      set -exuo pipefail
      echo hi
    SHELL

    connect from: "flasker", to: "otel-collector"
  end

  connect from: "grafana",        to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus",     to: "otel-collector"
end
