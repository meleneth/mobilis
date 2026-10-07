# frozen_string_literal: true

require "spec_helper"

RSpec.describe "HTTP service topology" do
  let(:system) { Mobilis::System.new("migration") }
  let(:dsl) { Mobilis::DSL::DSLContext.new(system) }

  def realize
    Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
  end

  it "models archetypes, connections, routes and SQLAlchemy in the existing graph and round trips them" do
    db = dsl.postgres("store")
    collector = dsl.otel_collector("telemetry")
    legacy = dsl.fastapi("legacy_api", port: 8100)
    model = legacy.add_sqlalchemy_model("Item", table: "items") do |m|
      m.column("id", "Integer", python_type: "int", primary_key: true)
      m.column("name", "String(80)", python_type: "str", unique: true)
    end
    candidate = dsl.go_http("candidate")
    proxy = dsl.envoy("gateway")
    [legacy, candidate].each do |service|
      dsl.connect(from: service, to: db)
      dsl.connect(from: service, to: collector)
    end
    dsl.connect(from: proxy, to: collector)
    dsl.route(from: proxy, to: legacy, candidate: candidate, mirror_percent: 100, candidate_percent: 0)
    loaded = Mobilis::System.from_json(system.to_json)
    expect(loaded[legacy.id].models.first.to_h).to eq(model.to_h)
    expect(loaded[proxy.id].extra_depends_on.last[:http_route]).to eq(weight: 0, mirror_percent: 100)
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:test))
    api = env.realized_node_by_name("legacy-api")
    expect(api.database.name).to eq("store")
    expect(api.collector.name).to eq("telemetry")
    expect(api.compose.clean_shrunk[:environment]).to include("DATABASE_URL=${LEGACY_API_DATABASE_URL}", "OTEL_EXPORTER_OTLP_ENDPOINT=http://telemetry:4318")
    expect(api.compose.clean_shrunk[:depends_on].keys).to include(:store, :telemetry)
  end

  it "loads legacy name-only dependencies" do
    api = dsl.fastapi("api")
    db = dsl.postgres("store")
    raw = system.to_h
    raw[:nodes].first[:extra_depends_on] = [db.name]
    loaded = Mobilis::System.from_h(raw)
    expect(loaded[api.id].extra_depends_on.first[:target]).to eq(loaded[db.id])
  end

  it "rejects ambiguous database connections and models without a database" do
    api = dsl.fastapi("api")
    api.add_sqlalchemy_model("Item")
    expect { realize }.to raise_error(ArgumentError, /require a PostgreSQL/)
    dsl.connect(from: api, to: dsl.postgres("one"))
    dsl.connect(from: api, to: dsl.postgres("two"))
    expect { realize }.to raise_error(ArgumentError, /one PostgreSQL/)
  end

  it "rejects invalid migration settings" do
    proxy = dsl.envoy("gateway")
    backend = dsl.fastapi("api")
    expect { dsl.route(from: proxy, to: backend, mirror_percent: 101) }.to raise_error(ArgumentError)
    expect { dsl.route(from: proxy, to: backend, candidate_percent: 1) }.to raise_error(ArgumentError)
    expect { realize }.to raise_error(ArgumentError, /default HTTP route/)
  end

  it "keeps connected collectors independent and exports collision-free environment values" do
    one = dsl.otel_collector("first-traces")
    two = dsl.otel_collector("second-traces")
    api = dsl.fastapi("api")
    worker = dsl.go_http("worker")
    dsl.connect(from: api, to: one)
    dsl.connect(from: worker, to: two)
    env = realize
    values = env.all_envfile_vars.group_by(&:envfile_name)
    expect(values.values.all? { |vars| vars.map(&:value).uniq.size == 1 }).to be(true)
    expect(env.realized_node_by_name("api").compose.clean_shrunk[:environment]).to include("OTEL_EXPORTER_OTLP_ENDPOINT=http://first-traces:4318")
    expect(env.realized_node_by_name("worker").compose.clean_shrunk[:environment]).to include("OTEL_EXPORTER_OTLP_ENDPOINT=http://second-traces:4318")
    dsl.connect(from: api, to: two)
    expect { realize }.to raise_error(ArgumentError, /one collector/)
  end

  it "rejects unsupported database connections and unknown serialized references" do
    api = dsl.go_http("api")
    dsl.connect(from: api, to: dsl.mysql("mysql"))
    expect { realize }.to raise_error(ArgumentError, /PostgreSQL/)
    raw = system.to_h
    raw[:nodes].first[:extra_depends_on] = ["missing"]
    expect { Mobilis::System.from_h(raw) }.to raise_error(ArgumentError, /Unknown dependency missing/)
  end

  it "renders every migration step with independent mirror and response weights" do
    legacy = dsl.fastapi("legacy")
    candidate = dsl.go_http("candidate", port: 9100)
    proxy = dsl.envoy("gateway")
    collector = dsl.otel_collector("telemetry")
    dsl.connect(from: proxy, to: collector)
    [[0, 0], [10, 0], [100, 0], [100, 1], [100, 10], [100, 50], [0, 100]].each do |mirror, authority|
      proxy.extra_depends_on.reject! { |edge| edge[:http_route] }
      dsl.route(from: proxy, to: legacy, candidate: candidate, mirror_percent: mirror, candidate_percent: authority)
      env = realize
      node = env.realized_node_by_name("gateway")
      config = Mobilis::ServiceWriter::Envoy.new(nil, env, node).configuration
      manager = config[:static_resources][:listeners].first[:filter_chains].first[:filters].first[:typed_config]
      action = manager[:route_config][:virtual_hosts].first[:routes].first[:route]
      expect(action[:weighted_clusters][:clusters].map { |cluster| cluster.slice(:name, :weight) }).to eq([{name: "legacy", weight: 100 - authority}, {name: "candidate", weight: authority}])
      expect(action[:weighted_clusters][:clusters].first[:request_headers_to_add]).to eq([
        {header: {key: "x-mobilis-mirror-cluster", value: "candidate"}, append_action: "OVERWRITE_IF_EXISTS_OR_ADD"}
      ])
      expect(action[:weighted_clusters][:clusters].last).not_to have_key(:request_headers_to_add)
      expect(action[:request_mirror_policies].first[:cluster_header]).to eq("x-mobilis-mirror-cluster")
      expect(action[:request_mirror_policies].first[:request_headers_mutations]).to eq([
        {append: {header: {key: "x-mobilis-shadow", value: "true"}, append_action: "OVERWRITE_IF_EXISTS_OR_ADD"}},
        {remove: "x-mobilis-mirror-cluster"}
      ])
      expect(manager[:http_filters].map { |filter| filter[:name] }).to eq(%w[envoy.filters.http.header_mutation envoy.filters.http.router])
      expect(manager[:http_filters].first[:typed_config][:mutations][:request_mutations]).to eq([
        {remove: "x-mobilis-shadow"}, {remove: "x-mobilis-mirror-cluster"}
      ])
      expect(action.fetch(:request_mirror_policies, []).size).to eq(1)
      expect(action[:request_mirror_policies].first[:runtime_fraction][:default_value][:numerator]).to eq(mirror)
      expect(action[:weighted_clusters][:runtime_key_prefix]).to eq("migration.authority")
      expect(action[:request_mirror_policies].first[:runtime_fraction][:runtime_key]).to eq("migration.mirror")
      expect(config[:layered_runtime][:layers]).to eq([{name: "admin", admin_layer: {}}])
      expect(manager[:tracing][:provider][:typed_config][:service_name]).to eq("gateway")
      clusters = config[:static_resources][:clusters]
      expect(clusters.last[:load_assignment][:endpoints].first[:lb_endpoints].first[:endpoint][:address][:socket_address]).to eq(address: "telemetry", port_value: 4317)
      expect(node.compose.clean_shrunk[:volumes]).to include("./gateway/envoy.yaml:/etc/envoy/envoy.yaml")
    end
  end

  it "keeps a separate shadow backend out of authoritative selection and round trips it" do
    legacy = dsl.fastapi("legacy")
    candidate = dsl.go_http("candidate")
    shadow = dsl.go_http("candidate-shadow")
    proxy = dsl.envoy("gateway")
    dsl.route(from: proxy, to: legacy, candidate: candidate, shadow: shadow, mirror_percent: 0, candidate_percent: 100)
    loaded = Mobilis::System.from_json(system.to_json)
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:test))
    config = Mobilis::ServiceWriter::Envoy.new(nil, env, env.realized_node_by_name("gateway")).configuration
    manager = config[:static_resources][:listeners].first[:filter_chains].first[:filters].first[:typed_config]
    action = manager[:route_config][:virtual_hosts].first[:routes].first[:route]
    expect(action[:weighted_clusters][:clusters].map { |cluster| cluster.slice(:name, :weight) }).to eq([{name: "legacy", weight: 0}, {name: "candidate", weight: 100}])
    expect(action[:request_mirror_policies].first[:cluster_header]).to eq("x-mobilis-mirror-cluster")
    expect(action[:weighted_clusters][:clusters].first[:request_headers_to_add].first[:header][:value]).to eq("candidate-shadow")
    expect(action[:request_mirror_policies].first[:runtime_fraction][:default_value][:numerator]).to eq(0)
    proxy.extra_depends_on.find { |edge| edge[:http_route] && edge[:http_route][:mirror_only] }[:http_route][:weight] = 1
    proxy.extra_depends_on.find { |edge| edge[:http_route] && edge[:target] == candidate }[:http_route][:weight] = 99
    expect { realize }.to raise_error(ArgumentError, /Mirror-only/)
    expect { dsl.route(from: dsl.envoy("other"), to: legacy, candidate: candidate, shadow: candidate) }.to raise_error(ArgumentError, /distinct/)
  end

  it "keeps backends private and deterministic routing on an unpublished verification listener" do
    legacy = dsl.fastapi("legacy", publish_port: false)
    candidate = dsl.go_http("candidate", publish_port: false)
    proxy = dsl.envoy("gateway", verification_port: 8081)
    dsl.route(from: proxy, to: legacy, candidate: candidate, mirror_percent: 100, candidate_percent: 10)
    loaded = Mobilis::System.from_json(system.to_json)
    env = Mobilis::RealizedEnv.new(loaded, Mobilis::ExecutionEnvironment.new(:test))
    %w[legacy candidate].each do |name|
      expect(env.realized_node_by_name(name).compose.clean_shrunk).not_to have_key(:ports)
    end
    node = env.realized_node_by_name("gateway")
    config = Mobilis::ServiceWriter::Envoy.new(nil, env, node).configuration
    listeners = config[:static_resources][:listeners]
    actions = listeners.map { |listener| listener[:filter_chains].first[:filters].first[:typed_config][:route_config][:virtual_hosts].first[:routes].first[:route] }
    expect(actions.first[:weighted_clusters]).not_to have_key(:header_name)
    expect(actions.last[:weighted_clusters][:header_name]).to eq("x-mobilis-routing-bucket")
    expect(actions.last[:request_mirror_policies]).to eq(actions.first[:request_mirror_policies])
    expect(node.compose.clean_shrunk[:ports].join).not_to include("8081", "9901")
    expect(loaded[proxy.id].verification_port).to eq(8081)
    expect(loaded[legacy.id].publish_port).to be(false)
    expect(loaded[candidate.id].publish_port).to be(false)
  end

  it "rejects invalid or conflicting verification ports" do
    [0, 65536, 8080, 9901, 9902].each do |port|
      expect { dsl.envoy("gateway-#{port}", verification_port: port) }.to raise_error(ArgumentError)
    end
  end

  it "infers an ordinary proxy route from a single HTTP connection without telemetry" do
    proxy = dsl.envoy("gateway")
    dsl.connect(from: proxy, to: dsl.fastapi("api"))
    env = realize
    config = Mobilis::ServiceWriter::Envoy.new(nil, env, env.realized_node_by_name("gateway")).configuration
    manager = config[:static_resources][:listeners].first[:filter_chains].first[:filters].first[:typed_config]
    expect(manager).not_to have_key(:tracing)
    expect(config).not_to have_key(:admin)
    expect(manager[:route_config][:virtual_hosts].first[:routes].first[:route]).to eq(cluster: "api")
  end
end
