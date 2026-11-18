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
  legacy.embedded_archive("legacy-source", payload: Mobilis::EmbeddedArchive.pack(files: {
    "src/service_legacy/routes.py" => File.binread(File.join(__dir__, "routes.py")),
    "src/service_legacy/items.py" => File.binread(File.join(__dir__, "items.py")),
    "tests/test_items.py" => File.binread(File.join(__dir__, "test_items.py")),
    "demo/operations.py" => File.binread(File.join(__dir__, "operations.py")),
    "demo/test_operations.py" => File.binread(File.join(__dir__, "test_operations.py")),
    "demo/sql_meaning.py" => File.binread(File.join(__dir__, "sql_meaning.py"))
  }))

  candidate = go_http("candidate", publish_port: false)
  candidate.embedded_archive("candidate-source", payload: Mobilis::EmbeddedArchive.pack(files: {
    "internal/app/routes.go" => File.binread(File.join(__dir__, "routes.go")),
    "internal/app/routes_test.go" => File.binread(File.join(__dir__, "routes_test.go")),
    "internal/app/items.go" => File.binread(File.join(__dir__, "items.go"))
  }))
  gateway = envoy("gateway", verification_port: 8081)
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
  gateway.embedded_archive("demo-commands", destination_prefix: "..", payload: Mobilis::EmbeddedArchive.pack(files: {
    "seed" => {content: File.binread(File.join(__dir__, "demo-operation")), executable: true},
    "exercise" => {content: File.binread(File.join(__dir__, "demo-operation")), executable: true},
    "verify" => {content: File.binread(File.join(__dir__, "demo-operation")), executable: true},
    "migration" => {content: File.binread(File.join(__dir__, "demo-operation")), executable: true},
    "test" => {content: File.binread(File.join(__dir__, "test")), executable: true},
    "demo" => {content: File.binread(File.join(__dir__, "demo")), executable: true},
    "demo-env" => File.binread(File.join(__dir__, "demo-env")),
    "README.md" => File.binread(File.join(__dir__, "README.md"))
  }))
  [legacy, candidate].each do |service|
    connect(from: service, to: db)
    connect(from: service, to: traces)
  end
  connect(from: gateway, to: traces)
  route(from: gateway, to: legacy, candidate: candidate,
    mirror_percent: mirror_percent, candidate_percent: candidate_percent)
end
