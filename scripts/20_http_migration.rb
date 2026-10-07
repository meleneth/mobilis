#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates a self-contained HTTP migration lab:
#
#   23 directories / 54 files
#   - FastAPI legacy service
#   - Go replacement service
#   - PostgreSQL
#   - Envoy traffic mirroring and progressive cutover
#   - OpenTelemetry + Jaeger
#   - dev/test Compose environments
#   - unit and integration tests
#   - seed/exercise/verify/migration operations
#   - trace, effect, and bounded SQL-semantic verification
#
# Run this script once to generate the project; the resulting system
# builds, runs, tests, and operates independently of Mobilis.

# or just go look at https://github.com/meleneth/strangler-fig-demo

# this overstates the 'while services remain live' angle because envoy is getting restarted to change percentages,
# but that's an implementation detail left to the reader

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

  legacy.add_model(Mobilis::Model::File.new("src/service_legacy/items.py", File.read(File.join(__dir__, "http_migration/items.py"))))
  legacy.add_model(Mobilis::Model::File.new("tests/test_items.py", File.read(File.join(__dir__, "http_migration/test_items.py"))))

  candidate = go_http("candidate", publish_port: false)
  candidate.add_model(Mobilis::Model::File.new("internal/app/routes.go", File.read(File.join(__dir__, "http_migration/routes.go"))))
  candidate.add_model(Mobilis::Model::File.new("internal/app/routes_test.go", File.read(File.join(__dir__, "http_migration/routes_test.go"))))
  candidate.add_model(Mobilis::Model::File.new("internal/app/items.go", File.read(File.join(__dir__, "http_migration/items.go"))))
  gateway = envoy("gateway", verification_port: 8081)
  legacy.add_model(Mobilis::Model::File.new("demo/operations.py", File.read(File.join(__dir__, "http_migration/operations.py"))))
  legacy.add_model(Mobilis::Model::File.new("demo/test_operations.py", File.read(File.join(__dir__, "http_migration/test_operations.py"))))
  legacy.add_model(Mobilis::Model::File.new("demo/sql_meaning.py", File.read(File.join(__dir__, "http_migration/sql_meaning.py"))))
  legacy.add_model(Mobilis::Model::File.new("demo/requirements.txt", "sqlglot==27.29.0\n"))
  legacy.add_model(Mobilis::Model::File.new("Dockerfile", <<~DOCKER))
    FROM #{Mobilis::ContainerVersions::PYTHON}
    WORKDIR /app
    COPY . .
    RUN pip install --no-cache-dir . -r demo/requirements.txt
    EXPOSE 8000
    CMD ["legacy"]
  DOCKER
  legacy.add_model(Mobilis::Model::File.new("demo/initial-state.json", {mirror: mirror_percent, candidate: candidate_percent}.to_json))
  %w[seed exercise verify migration].each do |operation|
    wrapper = File.read(File.join(__dir__, "http_migration/demo-operation"))
    gateway.add_model(Mobilis::Model::File.new("../#{operation}", wrapper, executable: true))
  end
  gateway.add_model(Mobilis::Model::File.new("../test", File.read(File.join(__dir__, "http_migration/test")), executable: true))
  gateway.add_model(Mobilis::Model::File.new("../demo", File.read(File.join(__dir__, "http_migration/demo")), executable: true))
  gateway.add_model(Mobilis::Model::File.new("../demo-env", File.read(File.join(__dir__, "http_migration/demo-env"))))
  gateway.add_model(Mobilis::Model::File.new("../README.md", File.read(File.join(__dir__, "http_migration/README.md"))))
  [legacy, candidate].each do |service|
    connect(from: service, to: db)
    connect(from: service, to: traces)
  end
  connect(from: gateway, to: traces)
  route(from: gateway, to: legacy, candidate: candidate,
    mirror_percent: mirror_percent, candidate_percent: candidate_percent)
end
