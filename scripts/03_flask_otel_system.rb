#!/usr/bin/env ruby

require "mobilis"

system = Mobilis::System.new("otel-generate")

flasker = Mobilis::Node::Flask.new("flasker")
otel_collector = Mobilis::Node::OtelCollector.new("otel-collector")
grafana = Mobilis::Node::Grafana.new("grafana")
jaeger = Mobilis::Node::Jaeger.new("jaeger")
prometheus = Mobilis::Node::Prometheus.new("prometheus")

# extra_depends_on = services you need to be able to open connections to

flasker.extra_depends_on << otel_collector

flasker.add_script("some_script.sh", <<~SHELL)
  #!/bin/bash
  set -exuo pipefail
  echo hi
SHELL

grafana.extra_depends_on << prometheus
otel_collector.extra_depends_on << jaeger
prometheus.extra_depends_on << otel_collector

system << flasker
system << otel_collector
system << grafana
system << jaeger
system << prometheus

manifest = Mobilis::Manifest.new(system)

manifest.materialize
