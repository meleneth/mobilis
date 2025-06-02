#!/usr/bin/env ruby

require "mobilis"

system = Mobilis::System.new("otel-generate")

# rails = Mobilis::Node::Rails.new("user")
# user_db = Mobilis::Node::PostgreSQL.new("user-db")
otel_collector = Mobilis::Node::OtelCollector.new("otel-collector")
grafana = Mobilis::Node::Grafana.new("grafana")
jaeger = Mobilis::Node::Jaeger.new("jaeger")
prometheus = Mobilis::Node::Prometheus.new("prometheus")

# extra_depends_on = services you need to be able to open connections to

# rails.primary_database = user_db
# rails.extra_depends_on << otel_collector

grafana.extra_depends_on << prometheus
otel_collector.extra_depends_on << jaeger
prometheus.extra_depends_on << otel_collector

# system << rails
# system << user_db
system << otel_collector
system << grafana
system << jaeger
system << prometheus

manifest = Mobilis::Manifest.new(system)

manifest.materialize
