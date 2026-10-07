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
end
