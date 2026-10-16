#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

# Generates an independent single-node Cassandra write/read example.
Mobilis::DSL.generate("cassandra-demo") do
  db = cassandra("history") do |node|
    node.datacenter("datacenter1")
    node.keyspace("approvals")
    node.schema_file(File.join(__dir__, "cassandra/schema.cql"))
  end
  api = fastapi("records")
  api.add_model(Mobilis::Model::File.new("src/service_records/routes.py", File.read(File.join(__dir__, "cassandra/routes.py"))))
  api.add_model(Mobilis::Model::File.new("demo/run.py", File.read(File.join(__dir__, "cassandra/run.py")), executable: true))
  connect(from: api, to: db)
  if ENV["CASSANDRA_DEMO_OTEL"] == "1"
    collector = otel_collector("telemetry")
    connect(from: api, to: collector)
  end
end
