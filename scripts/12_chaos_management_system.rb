#!/usr/bin/env ruby
require "mobilis"

# Chaos Management System
#

# Since this is the first real client app, documenting 'things' is needed.

# this is a rails / hotwire app.  I hope to understand what that means by the end.
#
# Start by echoing the applica.tion cookies

# We want:
# rails
# postgres
# telemetry
# redis (because when do we like slow things)
#

# Floor Talk
# open chat, per-object
#

Mobilis::DSL.generate("generate") do
  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  logs = loki("loki")
  prometheus("prometheus")
  promtail("promtail", loki: logs)

  connect from: "grafana",        to: "loki"
  connect from: "grafana",        to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus",     to: "otel-collector"

  rails("chaosmanagement", primary_database: postgres("chaosmanagement-db")) do |svc|
    svc.use_rspec!
    svc.use_haml!
    svc.use_tailwind!
    svc.use_uuid_primary_keys!
    svc.add_rails_model("user") do |m|
      m.string "name"
      m.string "avatar_url"
    end
    svc.add_rails_model("meeting")
    svc.add_rails_model("agenda")
    svc.add_rails_model("proposal")
    svc.add_rails_model("agreement")

  end
  connect from: "chaosmanagement", to: "otel-collector"
end
