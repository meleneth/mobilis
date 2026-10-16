#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("federation-demo") do
  sites_db = postgres("sites-db")
  deployments_db = postgres("deployments-db")

  sites = fastapi("sites", publish_port: false) do |service|
    service.graphql_subgraph("sites", source: File.join(__dir__, "federation/sites_schema.py"))
    service.add_sqlalchemy_model("SiteRecord", table: "sites") do |model|
      model.column("id", "Integer", python_type: "int", primary_key: true)
      model.column("name", "String(80)", python_type: "str")
    end
    service.add_model(Mobilis::Model::File.new("demo/seed.py", File.read(File.join(__dir__, "federation/seed_sites.py"))))
    service.add_model(Mobilis::Model::File.new("demo/verify.py", File.read(File.join(__dir__, "federation/verify.py"))))
    service.add_model(Mobilis::Model::File.new("demo/verify_traces.py", File.read(File.join(__dir__, "federation/verify_traces.py"))))
    service.add_model(Mobilis::Model::File.new("demo/integration", File.read(File.join(__dir__, "federation/integration")), executable: true))
    service.add_model(Mobilis::Model::File.new("tests/test_schema.py", File.read(File.join(__dir__, "federation/test_sites.py"))))
  end
  connect(from: sites, to: sites_db)

  deployments = fastapi("deployments", publish_port: false) do |service|
    service.graphql_subgraph("deployments", source: File.join(__dir__, "federation/deployments_schema.py"))
    service.add_sqlalchemy_model("DeploymentRecord", table: "deployments") do |model|
      model.column("id", "Integer", python_type: "int", primary_key: true)
      model.column("site_id", "Integer", python_type: "int")
      model.column("status", "String(40)", python_type: "str")
    end
    service.add_model(Mobilis::Model::File.new("demo/seed.py", File.read(File.join(__dir__, "federation/seed_deployments.py"))))
    service.add_model(Mobilis::Model::File.new("tests/test_schema.py", File.read(File.join(__dir__, "federation/test_deployments.py"))))
  end
  connect(from: deployments, to: deployments_db)

  gateway = grafbase("gateway")
  %w[invalid.toml invalid-sites.graphql invalid-deployments.graphql].each do |filename|
    gateway.add_model(Mobilis::Model::File.new("demo/#{filename}", File.read(File.join(__dir__, "federation/#{filename}"))))
  end
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
