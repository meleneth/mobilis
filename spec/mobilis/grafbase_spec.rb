# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Grafbase federation" do
  def topology(source)
    system = Mobilis::System.new("federation-test")
    dsl = Mobilis::DSL::DSLContext.new(system)
    gateway = dsl.grafbase("gateway", port: 5050)
    sites = dsl.fastapi("sites", publish_port: false) do |service|
      service.graphql_subgraph("sites", source: source)
    end
    dsl.connect(from: gateway, to: sites)
    [system, dsl, gateway, sites]
  end

  it "packages Python schema source and round trips the graph" do
    Dir.mktmpdir do |dir|
      source = "#{dir}/schema.py"
      File.write(source, "import strawberry\n@strawberry.type\nclass Query:\n    hello: str = 'world'\nschema = strawberry.federation.Schema(query=Query)\n")
      system, = topology(source)
      loaded = Mobilis::System.from_json(system.to_json)
      service = loaded.config_nodes.values.find { |node| node.name == "sites" }
      expect(service.graphql_subgraph_name).to eq("sites")
      expect(service.models.find { |model| model.path.end_with?("graphql_schema.py") }.content).to include("hello")
    end
  end

  it "rejects a missing source and a gateway without connected subgraphs" do
    system = Mobilis::System.new("invalid")
    dsl = Mobilis::DSL::DSLContext.new(system)
    service = dsl.fastapi("sites")
    expect { service.graphql_subgraph("sites", source: "missing.py") }.to raise_error(ArgumentError, /missing/)
    dsl.grafbase("gateway")
    expect { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test)) }.to raise_error(ArgumentError, /at least one/)
  end

  [false, true].each do |telemetry|
    it "generates a local composer, gateway and Strawberry router with telemetry #{telemetry}" do
      Dir.mktmpdir do |dir|
        source = "#{dir}/schema.py"
        File.write(source, "import strawberry\n@strawberry.type\nclass Query:\n    hello: str = 'world'\nschema = strawberry.federation.Schema(query=Query)\n")
        system, dsl, gateway, sites = topology(source)
        if telemetry
          collector = dsl.otel_collector("traces")
          dsl.connect(from: gateway, to: collector)
          dsl.connect(from: sites, to: collector)
        end
        env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:development))
        realized_gateway = env.realized_node_by_name("gateway")
        realized_service = env.realized_node_by_name("sites")
        fragment = realized_gateway.service_wrapped_compose
        expect(fragment[:services]).to have_key("gateway-composer")
        expect(fragment[:services]["gateway"][:depends_on]["gateway-composer"][:condition]).to eq("service_completed_successfully")
        expect(fragment[:services]["gateway"][:ports].length).to eq(1)
        Dir.chdir(dir) do
          realized_gateway.service_writer.new(nil, env, realized_gateway).write
          config = File.read("compose.toml")
          expect(config).to include("[subgraphs.sites]", "http://sites:8000/graphql")
          expect(File.read("gateway.toml").include?("trace_context = true")).to eq(telemetry)
          Dir.mkdir("app")
          Dir.chdir("app") { realized_service.service_writer.new(nil, env, realized_service).write }
          expect(File.read("app/pyproject.toml")).to include("strawberry-graphql[fastapi]")
          expect(File.read("app/src/service_sites/app.py")).to include("GraphQLRouter(schema")
          expect(system("python3", "-m", "compileall", "-q", "app/src")).to be(true)
        end
      end
    end
  end
end
