#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("initial") do
  deploy_kubernetes "*.deva.station" do
    istio do
      expose "app", root: true
      expose "jaeger"
      expose "grafana"
    end
  end

  rails("app", api: true) do |svc|
    svc.write_file("config/routes.rb", <<~RAILS)
      Rails.application.routes.draw do
        root "demo#index"
        get "/metrics", to: "demo#metrics"
        get "/up", to: "rails/health#show", as: :rails_health_check
      end
    RAILS
    svc.write_file("config/initializers/demo_hosts.rb", <<~RAILS)
      Rails.application.config.hosts += %w[initial.dev.deva.station initial.test.deva.station initial.prod.deva.station app]
    RAILS
    svc.write_file("app/controllers/demo_controller.rb", <<~RAILS)
      class DemoController < ActionController::API
        REQUESTS = { count: 0, mutex: Mutex.new }

        def index
          count = REQUESTS[:mutex].synchronize { REQUESTS[:count] += 1 }
          Instrumentation.trace("demo.request", attributes: { request_count: count }) do
            Rails.logger.info("Kubernetes demo request \#{count}")
            render json: { project: "initial", message: "Hello from Kubernetes and Istio", requests: count }
          end
        end

        def metrics
          count = REQUESTS[:mutex].synchronize { REQUESTS[:count] }
          render plain: "# HELP mobilis_demo_requests_total Demo requests\\n# TYPE mobilis_demo_requests_total counter\\nmobilis_demo_requests_total \#{count}\\n",
                 content_type: "text/plain; version=0.0.4"
        end
      end
    RAILS
  end

  grafana("grafana")
  jaeger("jaeger")
  logs = loki("loki")
  otel_collector("otel-collector")
  prometheus("prometheus") do |svc|
    svc.write_file("prometheus.yml", <<~YAML)
      global:
        scrape_interval: 5s
      scrape_configs:
        - job_name: otel_collector
          static_configs:
            - targets: ["otel-collector:9464"]
        - job_name: app
          static_configs:
            - targets: ["app:80"]
    YAML
  end
  alloy("alloy", loki: logs)

  connect from: "app", to: "otel-collector"
  connect from: "grafana", to: "loki"
  connect from: "grafana", to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus", to: "otel-collector"
end

puts "From generate/: ./deploy-kubernetes dev"
