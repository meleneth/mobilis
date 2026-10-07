# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"
require_relative "../../examples/http_migration/system"

RSpec.describe "HTTP migration demo" do
  it "renders normal service artifacts and Compose for all environments without materializing" do
    Dir.mktmpdir do |dir|
      output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "scripts/20_http_migration.rb", "--render", dir)
      expect(status.success?).to be(true), output
      expect(File).not_to exist("#{dir}/.git")
      %w[test development production].each do |env|
        compose = YAML.safe_load_file("#{dir}/#{env}-compose.yml")
        expect(compose["services"].keys).to eq(%w[store telemetry trace-viewer legacy candidate gateway])
        expect(compose["services"]["legacy"]["build"]).to eq("context" => "./legacy")
        expect(compose["services"]["candidate"]["environment"]).to include("DATABASE_URL=${CANDIDATE_DATABASE_URL}")
        vars = File.readlines("#{dir}/#{env}.env", chomp: true).to_h { |line| line.split("=", 2) }
        expect(vars["LEGACY_DATABASE_URL"]).to eq(vars["CANDIDATE_DATABASE_URL"])
        expect(vars["LEGACY_DATABASE_URL"]).to include("store-#{env}-user", "store_#{env}")
      end
      collector = YAML.safe_load_file("#{dir}/telemetry/otel-collector-config.yaml")
      expect(collector["exporters"]["otlp"]["endpoint"]).to eq("trace-viewer:4317")
      python = File.read("#{dir}/legacy/src/service_legacy/routes.py")
      go = File.read("#{dir}/candidate/internal/app/routes.go")
      expect(python).to include('app.get("/items")', "select(Item).order_by(Item.id)")
      expect(go).to include('"GET /items"', "deps.DB.Query(r.Context()", "SELECT id, name FROM items ORDER BY id")
      expect(python + go).not_to include("start_as_current_span", "otel.Tracer")
      loaded = Mobilis::System.from_json(File.read("#{dir}/mobilis-system.json"))
      expect(loaded.node_count).to eq(6)
    end
  end

  it "preserves health-check connection settings across serialization" do
    system = HTTPMigrationDemo.system
    legacy = system.config_nodes.values.find { |n| n.name == "legacy" }
    legacy.extra_depends_on.first[:force_skip_health_checks] = true
    loaded = Mobilis::System.from_json(system.to_json)
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:test))
    expect(env.realized_node_by_name("legacy").compose.clean_shrunk[:depends_on][:store][:condition]).to eq("service_started")
  end
end
