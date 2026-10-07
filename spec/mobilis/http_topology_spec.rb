# frozen_string_literal: true

require "spec_helper"

RSpec.describe "HTTP service topology" do
  let(:system) { Mobilis::System.new("migration") }
  let(:dsl) { Mobilis::DSL::DSLContext.new(system) }

  def realize
    Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
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
end
