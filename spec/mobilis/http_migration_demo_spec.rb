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
      go = File.read("#{dir}/candidate/internal/app/routes.go")
      expect(python).to include('app.get("/items")', "select(Item).order_by(Item.id)")
      expect(go).to include('"GET /items"', "deps.DB.Query(r.Context()", "SELECT id, name FROM items ORDER BY id")
      expect(python + go).not_to include("start_as_current_span", "otel.Tracer")
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
