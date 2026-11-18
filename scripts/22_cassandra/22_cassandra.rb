#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

# Generates an independent single-node Cassandra write/read example.
Mobilis::DSL.generate("cassandra-demo") do
  db = cassandra("history") do |node|
    node.datacenter("datacenter1")
    node.keyspace("approvals")
    node.embedded_archive("schema", payload: Mobilis::EmbeddedArchive.pack(files: {
      "schema.cql" => File.binread(File.join(__dir__, "schema.cql"))
    }))
  end
  api = fastapi("records")
  api.embedded_archive("application", payload: Mobilis::EmbeddedArchive.pack(files: {
    "src/service_records/routes.py" => File.binread(File.join(__dir__, "routes.py")),
    "demo/run.py" => {content: File.binread(File.join(__dir__, "run.py")), executable: true}
  }))
  connect(from: api, to: db)
  if ENV["CASSANDRA_DEMO_OTEL"] == "1"
    collector = otel_collector("telemetry")
    connect(from: api, to: collector)
  end
end
