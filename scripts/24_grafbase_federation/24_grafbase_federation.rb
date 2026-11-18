#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("federation-demo") do
  sites_db = postgres("sites-db")
  deployments_db = postgres("deployments-db")

  sites = fastapi("sites", publish_port: false) do |service|
    service.graphql_subgraph("sites")
    service.add_sqlalchemy_model("SiteRecord", table: "sites") do |model|
      model.column("id", "Integer", python_type: "int", primary_key: true)
      model.column("name", "String(80)", python_type: "str")
    end
    service.embedded_archive("sites-source", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_sites/graphql_schema.py" => File.binread(File.join(__dir__, "sites_schema.py")),
      "demo/seed.py" => File.binread(File.join(__dir__, "seed_sites.py")),
      "demo/verify.py" => File.binread(File.join(__dir__, "verify.py")),
      "demo/verify_traces.py" => File.binread(File.join(__dir__, "verify_traces.py")),
      "demo/integration" => {content: File.binread(File.join(__dir__, "integration")), executable: true},
      "tests/test_schema.py" => File.binread(File.join(__dir__, "test_sites.py"))
    }))
  end
  connect(from: sites, to: sites_db)

  deployments = fastapi("deployments", publish_port: false) do |service|
    service.graphql_subgraph("deployments")
    service.add_sqlalchemy_model("DeploymentRecord", table: "deployments") do |model|
      model.column("id", "Integer", python_type: "int", primary_key: true)
      model.column("site_id", "Integer", python_type: "int")
      model.column("status", "String(40)", python_type: "str")
    end
    service.embedded_archive("deployments-source", payload: Mobilis::EmbeddedArchive.pack(files: {
      "src/service_deployments/graphql_schema.py" => File.binread(File.join(__dir__, "deployments_schema.py")),
      "demo/seed.py" => File.binread(File.join(__dir__, "seed_deployments.py")),
      "tests/test_schema.py" => File.binread(File.join(__dir__, "test_deployments.py"))
    }))
  end
  connect(from: deployments, to: deployments_db)

  gateway = grafbase("gateway")
  gateway.embedded_archive("invalid-examples", payload: Mobilis::EmbeddedArchive.pack(files: {
    "demo/invalid.toml" => File.binread(File.join(__dir__, "invalid.toml")),
    "demo/invalid-sites.graphql" => File.binread(File.join(__dir__, "invalid-sites.graphql")),
    "demo/invalid-deployments.graphql" => File.binread(File.join(__dir__, "invalid-deployments.graphql"))
  }))
  connect(from: gateway, to: sites)
  connect(from: gateway, to: deployments)

  if ENV["FEDERATION_DEMO_OTEL"] == "1"
    sites.add_model(Mobilis::Model::File.new("demo/otel-enabled", "connected\n"))
    collector = otel_collector("telemetry")
    traces = jaeger("trace-viewer")
    connect(from: collector, to: traces)
    [gateway, sites, deployments].each { |service| connect(from: service, to: collector) }
  end
end
