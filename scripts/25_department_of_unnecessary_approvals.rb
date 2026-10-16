#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

source = File.join(__dir__, "dua")
Mobilis::DSL.generate("department-of-unnecessary-approvals") do
  applications_db = postgres("applications-db")
  decisions_db = cassandra("decisions-db") do |db|
    db.keyspace("approvals")
    db.schema_file(File.join(source, "schema.cql"))
  end
  events = google_pubsub("approval-events", project: "dua-local-project") do |broker|
    broker.topic("applications")
    broker.subscription("bureaucrat", topic: "applications")
  end

  applications = fastapi("applications", publish_port: false) do |service|
    service.graphql_subgraph("applications", source: File.join(source, "applications_schema.py"))
    service.add_sqlalchemy_model("ApplicationRecord", table: "applications") do |model|
      model.column("id", "String(36)", python_type: "str", primary_key: true)
      model.column("correlation_id", "String(36)", python_type: "str", unique: true)
      model.column("activity", "String(80)", python_type: "str")
      model.column("justification", "String(400)", python_type: "str")
    end
  end
  connect(from: applications, to: applications_db)
  connect(from: applications, to: events, publish: "applications")

  decisions = fastapi("decisions", publish_port: false) do |service|
    service.graphql_subgraph("decisions", source: File.join(source, "decisions_schema.py"))
  end
  connect(from: decisions, to: decisions_db)

  worker = go_http("bureaucrat", publish_port: false)
  connect(from: worker, to: events, subscribe: "bureaucrat")
  connect(from: worker, to: decisions_db)

  gateway = grafbase("gateway")
  connect(from: gateway, to: applications)
  connect(from: gateway, to: decisions)

  if ENV["DUA_OTEL"] == "1"
    collector = otel_collector("telemetry")
    connect(from: collector, to: jaeger("trace-viewer"))
    [applications, decisions, worker, gateway].each { |service| connect(from: service, to: collector) }
  end

  files = {
    applications => {"demo/verify.py" => "verify.py", "tests/test_dua.py" => "test_applications.py"},
    decisions => {"src/service_decisions/routes.py" => "decisions_routes.py", "tests/test_dua.py" => "test_decisions.py"},
    worker => {"internal/app/routes.go" => "worker.go", "internal/app/worker_test.go" => "worker_test.go"},
    gateway => {"../demo" => "demo", "../README.md" => "README.md"}
  }
  files.each do |service, entries|
    entries.each do |destination, filename|
      service.add_model(Mobilis::Model::File.new(destination, File.read(File.join(source, filename)),
                                                   executable: destination == "../demo"))
    end
  end
  worker.add_model(Mobilis::Model::File.new("internal/app/decision_recording.go",
    File.read(File.join(source, ENV["DUA_OTEL"] == "1" ? "worker_otel.go" : "worker_plain.go"))))
  if ENV["DUA_OTEL"] == "1"
    applications.add_model(Mobilis::Model::File.new("demo/otel-enabled", "connected\n"))
    applications.add_model(Mobilis::Model::File.new("demo/verify_traces.py", File.read(File.join(source, "verify_traces.py"))))
  end
end
