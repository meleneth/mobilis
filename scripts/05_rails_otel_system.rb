#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  rails("user-service", primary_database: postgres("user-db")) do |svc|
    svc.add_rails_model("user") do |m|
      m.string  "name"
      m.integer "score"
    end
    svc.write_file("lib/tasks/demo.rake", <<~HERE)
      namespace :demo do
        task :trace => :environment do
          5.times do
            Instrumentation.trace("demo.user.create", attributes: { score: rand(100) }) do
              User.create!(name: "BrrrUser", score: rand(100))
            end
          end
        end
      end
    HERE
  end

  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  logs = loki("loki")
  prometheus("prometheus")
  promtail("promtail", loki: logs)

  connect from: "user-service", to: "otel-collector"
  connect from: "grafana", to: "loki"
  connect from: "grafana", to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus", to: "otel-collector"
end

puts "Check out ./dc_test run user-service bundle exec rake demo:trace"
