#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

# Generates a self-contained Pub/Sub emulator exchange. Run demo/verify.py
# inside the generated publisher container after ./dc_dev up -d --wait.
Mobilis::DSL.generate("pubsub-demo") do
  events = google_pubsub("events", project: "mobilis-local", publish_port: true) do |broker|
    broker.topic("requests")
    broker.subscription("alpha", topic: "requests")
    broker.subscription("beta", topic: "requests")
  end

  publisher = fastapi("publisher", publish_port: false)
  publisher.add_model(Mobilis::Model::File.new("src/service_publisher/routes.py", File.read(File.join(__dir__, "pubsub/publisher_routes.py"))))
  publisher.add_model(Mobilis::Model::File.new("demo/verify.py", File.read(File.join(__dir__, "pubsub/verify.py")), executable: true))
  connect(from: publisher, to: events, publish: "requests")

  {"alpha-one" => "alpha", "alpha-two" => "alpha", "beta-worker" => "beta"}.each do |service_name, subscription|
    worker = fastapi(service_name, publish_port: false)
    worker.add_model(Mobilis::Model::File.new("src/service_#{service_name.tr('-', '_')}/routes.py",
                                                     File.read(File.join(__dir__, "pubsub/consumer_routes.py"))))
    connect(from: worker, to: events, subscribe: subscription)
  end

  if ENV["PUBSUB_DEMO_OTEL"] == "1"
    collector = otel_collector("telemetry")
    traces = jaeger("trace-viewer")
    connect(from: collector, to: traces)
    connect(from: publisher, to: collector)
    %w[alpha-one alpha-two beta-worker].each { |name| connect(from: name, to: collector) }
  end
end
