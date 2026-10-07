#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

mirror_percent = Integer(ENV.fetch("MIRROR_PERCENT", "100"))
candidate_percent = Integer(ENV.fetch("CANDIDATE_PERCENT", "0"))

Mobilis::DSL.generate("http-migration") do
  db = postgres("store")
  traces = otel_collector("telemetry")
  jaeger = jaeger("trace-viewer")
  connect(from: traces, to: jaeger)

  legacy = fastapi("legacy", publish_port: false)
  legacy.add_sqlalchemy_model("Item", table: "items") do |model|
    model.column("id", "Integer", python_type: "int", primary_key: true)
    model.column("name", "String(80)", python_type: "str", unique: true)
  end
  legacy.add_model(Mobilis::Model::File.new("src/service_legacy/routes.py", File.read(File.join(__dir__, "http_migration/routes.py"))))

  candidate = go_http("candidate", publish_port: false)
  candidate.add_model(Mobilis::Model::File.new("internal/app/routes.go", File.read(File.join(__dir__, "http_migration/routes.go"))))
  candidate.add_model(Mobilis::Model::File.new("internal/app/routes_test.go", File.read(File.join(__dir__, "http_migration/routes_test.go"))))
  gateway = envoy("gateway", verification_port: 8081)
  legacy.add_model(Mobilis::Model::File.new("demo/operations.py", File.read(File.join(__dir__, "http_migration/operations.py"))))
  legacy.add_model(Mobilis::Model::File.new("demo/test_operations.py", File.read(File.join(__dir__, "http_migration/test_operations.py"))))
  legacy.add_model(Mobilis::Model::File.new("demo/initial-state.json", {mirror: mirror_percent, candidate: candidate_percent}.to_json))
  %w[seed exercise verify migration].each do |operation|
    wrapper = File.read(File.join(__dir__, "http_migration/demo-operation"))
    gateway.add_model(Mobilis::Model::File.new("../#{operation}", wrapper, executable: true))
  end
  gateway.add_model(Mobilis::Model::File.new("../demo", File.read(File.join(__dir__, "http_migration/demo")), executable: true))
  gateway.add_model(Mobilis::Model::File.new("../README.md", File.read(File.join(__dir__, "http_migration/README.md"))))
  [legacy, candidate].each do |service|
    connect(from: service, to: db)
    connect(from: service, to: traces)
  end
  connect(from: gateway, to: traces)
  route(from: gateway, to: legacy, candidate: candidate,
    mirror_percent: mirror_percent, candidate_percent: candidate_percent)
end
