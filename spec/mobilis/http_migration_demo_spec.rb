# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "HTTP migration demo" do
  let(:system) do
    configured_system = nil
    manifest = instance_double(Mobilis::Manifest, materialize: nil)
    allow(Mobilis::Manifest).to receive(:new) do |value|
      configured_system = value
      manifest
    end
    load File.expand_path("../../scripts/20_http_migration.rb", __dir__)
    expect(manifest).to have_received(:materialize)
    configured_system
  end

  it "generates normal service artifacts and Compose for all environments" do
    %w[test development production].each do |environment|
      env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(environment))
      services = env.realized_nodes.to_h { |node| [node.name, node.service_wrapped_compose[:services][node.name]] }
      expect(services.keys).to eq(%w[store telemetry trace-viewer legacy candidate gateway])
      expect(services["legacy"][:build]).to eq(context: "./legacy")
      expect(services["candidate"][:environment]).to include("DATABASE_URL=${CANDIDATE_DATABASE_URL}")
      expect(services["legacy"]).not_to have_key(:ports)
      expect(services["candidate"]).not_to have_key(:ports)
      vars = env.all_envfile_vars.to_h { |var| [var.envfile_name, var.value] }
      expect(vars["LEGACY_DATABASE_URL"]).to eq(vars["CANDIDATE_DATABASE_URL"])
      expect(vars["LEGACY_DATABASE_URL"]).to include("store-#{environment}-user", "store_#{environment}")
    end

    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
    Dir.mktmpdir do |dir|
      env.realized_nodes.select(&:has_service_dir).each do |node|
        project = File.join(dir, node.name)
        FileUtils.mkdir_p(project)
        Dir.chdir(project) { node.service_writer.new(nil, env, node).write }
      end
      collector = YAML.safe_load_file("#{dir}/telemetry/otel-collector-config.yaml")
      expect(collector["exporters"]["otlp"]["endpoint"]).to eq("trace-viewer:4317")
      python = File.read("#{dir}/legacy/src/service_legacy/routes.py")
      python_store = File.read("#{dir}/legacy/src/service_legacy/items.py")
      go_store = File.read("#{dir}/candidate/internal/app/items.go")
      go = File.read("#{dir}/candidate/internal/app/routes.go")
      expect(python).to include('app.get("/items")', "store.list_items()")
      expect(python_store).to include("select(Item).order_by(Item.id)", "session.commit()")
      expect(go).to include('"GET /items"', "store.List(r.Context())")
      expect(go_store).to include("store.db.Query(ctx", "SELECT id, name FROM items ORDER BY id", "tx.Commit(ctx)")
      expect(python.split("@app.post").first).not_to include("start_as_current_span")
      expect(go.split('mux.HandleFunc("GET /items"').last.split('mux.HandleFunc("POST /items"').first).not_to include("otel.Tracer(")
      expect(python).to include('app.post("/items")', "store.commit(effect)", "item_logic.effect_attributes(effect,")
      expect(python_store).to include('"demo.write.mode"')
      expect(go).to include('"POST /items"', "determineEffect(value)", "commitItem(ctx, store, effect, shadow)", '"demo.write.effect"', '"demo.write.committed"')
      expect(go).not_to include("SHADOW_WRITES", "os.Getenv")
      expect(go.scan("effect := determineEffect(value)").size).to eq(1)
      expect(File.read("#{dir}/candidate/internal/app/routes_test.go")).to include("TestShadowSkipsOnlyCommitBoundary", "TestShadowRequestContext")
      expect(File.executable?("#{dir}/demo")).to be(true)
      expect(File.read("#{dir}/demo")).to include("source ./demo-env", "dc up -d", "./seed", "./migration", "./exercise", "./verify", "0 10 50")
      expect(File.read("#{dir}/demo-env")).to include("MOBILIS_ENV:-development", "./dc_dev", "./dc_test", "./dc_prod")
      expect(File.read("#{dir}/legacy/tests/test_items.py")).to include("flexmock(store)", "TestClient", "invented_database_method")
      expect(File.executable?("#{dir}/test")).to be(true)
      expect(File.read("#{dir}/test")).to include("pytest --cov=service_legacy", "go test -race -cover ./...")
      expect(File.read("#{dir}/test")).not_to include("dc_test", "docker", "--network")
      %w[seed migration exercise verify].each do |operation|
        expect(File.executable?("#{dir}/#{operation}")).to be(true)
        wrapper = File.read("#{dir}/#{operation}")
        expect(wrapper).to include("source ./demo-env", "dc run", "/app/demo/operations.py")
        expect(wrapper).not_to include("/home/", "--network", "mobilis/")
      end
      operations = File.read("#{dir}/legacy/demo/operations.py")
      expect(operations).to include("CREATE TRIGGER item_effect", "demo.write.effect", "exactly one authoritative insert", "disconnected evidence")
      expect(operations).to include("SQL meaning drift", "instrumented SQL meaning drift", "demo.sql.parameters")
      expect(File.read("#{dir}/legacy/demo/sql_meaning.py")).to include('read="postgres"', "unused SQL bindings")
      expect(File.read("#{dir}/legacy/Dockerfile")).to include("-r demo/requirements.txt")
      expect(File.read("#{dir}/README.md")).to include("./seed", "./migration 100 10", "./verify")
      expect(Mobilis::System.from_json(system.to_json).node_count).to eq(6)
    end
  end

  it "preserves health-check connection settings across serialization" do
    legacy = system.config_nodes.values.find { |node| node.name == "legacy" }
    legacy.extra_depends_on.first[:force_skip_health_checks] = true
    loaded = Mobilis::System.from_json(system.to_json)
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:test))
    expect(env.realized_node_by_name("legacy").compose.clean_shrunk[:depends_on][:store][:condition]).to eq("service_started")
  end
end

RSpec.describe Mobilis::Model::File do
  it "preserves executable permissions through graph serialization and writing" do
    model = described_class.new("helper", "#!/bin/sh\nexit 0\n", executable: true)
    loaded = described_class.from_h(model.to_h)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { loaded.write_file }
      expect(File.executable?("#{dir}/helper")).to be(true)
    end
    expect(described_class.from_h(path: "old", content: "old").executable).to be(false)
  end
end

RSpec.describe Mobilis::Plugin::WriteFiles do
  it "does not rewrite file models already consumed before HTTP image builds" do
    manifest = instance_double(Mobilis::Manifest)
    plugin = described_class.new(manifest)
    [Mobilis::Realized::FastAPI, Mobilis::Realized::GoHTTP, Mobilis::Realized::Envoy].each do |klass|
      node = klass.allocate
      expect(node).not_to receive(:each_model_of_type)
      allow(manifest).to receive(:each_node_of_type).and_yield(nil, node)
      plugin.hook_after_dc_helpers
    end
  end
end
