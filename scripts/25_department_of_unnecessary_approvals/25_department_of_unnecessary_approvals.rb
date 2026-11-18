#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("department-of-unnecessary-approvals") do
  applications_db = postgres("applications-db")
  decisions_db = cassandra("decisions-db") do |db|
    db.keyspace("approvals")
    db.embedded_archive("schema", payload: Mobilis::EmbeddedArchive.pack(files: {
      "schema.cql" => File.binread(File.join(__dir__, "schema.cql"))
    }))
  end
  events = google_pubsub("approval-events", project: "dua-local-project") do |broker|
    broker.topic("applications")
    broker.subscription("bureaucrat", topic: "applications")
  end

  applications = fastapi("applications", publish_port: false) do |service|
    service.graphql_subgraph("applications")
    service.add_sqlalchemy_model("ApplicationRecord", table: "applications") do |model|
      model.column("id", "String(36)", python_type: "str", primary_key: true)
      model.column("correlation_id", "String(36)", python_type: "str", unique: true)
      model.column("activity", "String(80)", python_type: "str")
      model.column("justification", "String(400)", python_type: "str")
      model.column("target_name", "String(80)", python_type: "str", nullable: true)
    end
    service.embedded_archive("application-source", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_applications/graphql_schema.py" => File.binread(File.join(__dir__, "applications_schema.py")),
      "demo/verify.py" => File.binread(File.join(__dir__, "verify.py")),
      "tests/test_dua.py" => File.binread(File.join(__dir__, "test_applications.py"))
    }))
  end
  connect(from: applications, to: applications_db)
  connect(from: applications, to: events, publish: "applications")

  decisions = fastapi("decisions", publish_port: false) do |service|
    service.graphql_subgraph("decisions")
    service.embedded_archive("decision-source", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_decisions/graphql_schema.py" => File.binread(File.join(__dir__, "decisions_schema.py")),
      "src/service_decisions/routes.py" => File.binread(File.join(__dir__, "decisions_routes.py")),
      "tests/test_dua.py" => File.binread(File.join(__dir__, "test_decisions.py"))
    }))
  end
  connect(from: decisions, to: decisions_db)

  worker = go_http("bureaucrat", publish_port: false)
  worker.embedded_archive("worker-source", payload: Mobilis::EmbeddedArchive.pack(files: {
    "internal/app/routes.go" => File.binread(File.join(__dir__, "worker.go")),
    "internal/app/worker_test.go" => File.binread(File.join(__dir__, "worker_test.go"))
  }))
  connect(from: worker, to: events, subscribe: "bureaucrat")
  connect(from: worker, to: decisions_db)

  gateway = grafbase("gateway")
  gateway.embedded_archive("demo", destination_prefix: "..", payload: Mobilis::EmbeddedArchive.pack(files: {
    "demo" => {content: File.binread(File.join(__dir__, "demo")), executable: true},
    "README.md" => File.binread(File.join(__dir__, "README.md")),
    ".gitignore" => File.binread(File.join(__dir__, ".gitignore"))
  }))
  connect(from: gateway, to: applications)
  connect(from: gateway, to: decisions)

  if ENV["DUA_OTEL"] == "1"
    worker.embedded_archive("worker-otel", payload: Mobilis::EmbeddedArchive.pack(files: {
      "internal/app/decision_recording.go" => File.binread(File.join(__dir__, "worker_otel.go"))
    }))
    applications.embedded_archive("application-otel", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_applications/resolver_spans.py" => File.binread(File.join(__dir__, "resolver_spans_otel.py")),
      "demo/verify_traces.py" => File.binread(File.join(__dir__, "verify_traces.py"))
    }))
    decisions.embedded_archive("decision-otel", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_decisions/resolver_spans.py" => File.binread(File.join(__dir__, "resolver_spans_otel.py"))
    }))
    collector = otel_collector("telemetry")
    connect(from: collector, to: jaeger("trace-viewer"))
    [applications, decisions, worker, gateway].each { |service| connect(from: service, to: collector) }
    applications.add_model(Mobilis::Model::File.new("demo/otel-enabled", "connected\n"))
  else
    worker.embedded_archive("worker-plain", payload: Mobilis::EmbeddedArchive.pack(files: {
      "internal/app/decision_recording.go" => File.binread(File.join(__dir__, "worker_plain.go"))
    }))
    applications.embedded_archive("application-plain", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_applications/resolver_spans.py" => File.binread(File.join(__dir__, "resolver_spans_plain.py"))
    }))
    decisions.embedded_archive("decision-plain", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_decisions/resolver_spans.py" => File.binread(File.join(__dir__, "resolver_spans_plain.py"))
    }))
  end
end
