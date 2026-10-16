# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Cassandra generation" do
  def build_system(telemetry: false)
    system = Mobilis::System.new("cass-demo")
    dsl = Mobilis::DSL::DSLContext.new(system)
    db = dsl.cassandra("history") { |node| node.keyspace("approvals") }
    api = dsl.fastapi("records")
    dsl.connect(from: api, to: db)
    dsl.connect(from: api, to: dsl.otel_collector("traces")) if telemetry
    system
  end

  it "serializes the DSL settings and rejects invalid identifiers" do
    system = build_system
    db = system.config_nodes.values.find { |node| node.is_a?(Mobilis::Node::Cassandra) }
    db.datacenter("west_1").version("4.1.12")
    loaded = Mobilis::System.from_json(system.to_json)
    restored = loaded.config_nodes.values.find { |node| node.is_a?(Mobilis::Node::Cassandra) }
    expect([restored.datacenter_name, restored.keyspace_name, restored.version_tag]).to eq(%w[west_1 approvals 4.1.12])
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:test))
    expect(env.realized_node_by_name("history").source_image).to eq("cassandra:4.1.12")
    expect { db.keyspace("bad-name") }.to raise_error(ArgumentError, /keyspace/)
    expect { db.version("latest;evil") }.to raise_error(ArgumentError, /version/)
  end

  [false, true].each do |telemetry|
    it "generates a connected native client with telemetry #{telemetry}" do
      system = build_system(telemetry: telemetry)
      env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:development))
      db = env.realized_node_by_name("history")
      api = env.realized_node_by_name("records")
      compose = api.compose.clean_shrunk
      expect(compose[:depends_on][:history][:condition]).to eq("service_healthy")
      expect(compose[:environment]).to include("CASSANDRA_CONTACT_POINTS=history", "CASSANDRA_PORT=9042", "CASSANDRA_DATACENTER=datacenter1", "CASSANDRA_KEYSPACE=approvals")
      expect(compose[:environment]).to include("CASSANDRA_USERNAME=${HISTORY_CASSANDRA_USER}", "CASSANDRA_PASSWORD=${HISTORY_CASSANDRA_PASSWORD}")
      expect(compose[:environment].any? { |entry| entry.start_with?("OTEL_EXPORTER_OTLP_ENDPOINT=") }).to eq(telemetry)
      expect(compose[:depends_on].key?(:traces)).to eq(telemetry)
      expect(db.compose.clean_shrunk[:healthcheck][:test].last).to include("SELECT release_version FROM system.local")
      expect(db.compose.clean_shrunk[:volumes]).to include("${HISTORY_CASSANDRA_DATA}:/var/lib/cassandra")
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          db.service_writer.new(nil, env, db).write
          expect(File.read("Dockerfile")).to include("FROM cassandra:4.1", "PasswordAuthenticator")
          expect(File.read("entrypoint.sh")).to include("CREATE KEYSPACE IF NOT EXISTS", "GRANT SELECT", "GRANT MODIFY", "mobilis-cassandra-ready")
          Dir.mkdir("api")
          Dir.chdir("api") { api.service_writer.new(nil, env, api).write }
          source = File.read("api/src/service_records/cassandra_client.py")
          expect(source).to include("from cassandra.cluster import Cluster", "PlainTextAuthProvider")
          expect(source).not_to include("SQLAlchemy")
          expect(source.include?("start_as_current_span")).to eq(telemetry)
          if telemetry
            expect(source).to include('"db.operation": operation', '"error.type"')
            expect(source).not_to include('"db.statement"', 'record_exception=True')
          end
          expect(File.read("api/pyproject.toml").include?("opentelemetry-sdk")).to eq(telemetry)
          expect(system("python3", "-m", "compileall", "-q", "api/src")).to be(true)
        end
      end
    end
  end

  it "refuses non-repeatable schema and emits production credential placeholders" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "schema.cql")
      File.write(path, "DROP TABLE records;\n")
      system = build_system
      system.config_nodes.values.find { |node| node.is_a?(Mobilis::Node::Cassandra) }.schema_file(path)
      env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:production))
      db = env.realized_node_by_name("history")
      expect(db.env_vars_for_env_file.map(&:env_repr)).to include("HISTORY_CASSANDRA_PASSWORD=REPLACE_CASSANDRA_PASSWORD")
      Dir.chdir(dir) do
        expect { db.service_writer.new(nil, env, db).write }.to raise_error(ArgumentError, /repeatable startup/)
      end
    end
  end

  it "passes Cassandra variables to other connected service types" do
    system = Mobilis::System.new("rack-cassandra")
    dsl = Mobilis::DSL::DSLContext.new(system)
    database = dsl.cassandra("history") { |node| node.keyspace("approvals") }
    dsl.connect(from: dsl.rack("worker"), to: database)
    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
    worker = env.realized_node_by_name("worker").compose.clean_shrunk
    expect(worker[:environment]).to include("CASSANDRA_CONTACT_POINTS=history", "CASSANDRA_KEYSPACE=approvals")
    expect(worker[:depends_on][:history][:condition]).to eq("service_healthy")
  end
end

RSpec.describe "Cassandra numbered example" do
  it "uses native driver files and an executable round trip" do
    configured = nil
    manifest = instance_double(Mobilis::Manifest, materialize: nil)
    allow(Mobilis::Manifest).to receive(:new) do |system|
      configured = system
      manifest
    end
    load File.expand_path("../../scripts/22_cassandra.rb", __dir__)
    expect(manifest).to have_received(:materialize)
    api = configured.config_nodes.values.find { |node| node.name == "records" }
    demo = api.models.find { |model| model.is_a?(Mobilis::Model::File) && model.path == "demo/run.py" }
    expect(demo.executable).to be(true)
    expect(demo.content).to include("from service_records.cassandra_client import execute", "SELECT note FROM records")
    expect(configured.config_nodes.values.map(&:name)).to eq(%w[history records])
  end
end
