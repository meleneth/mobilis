# frozen_string_literal: true

require "spec_helper"

RSpec.describe "HTTP service topology" do
  let(:system) { Mobilis::System.new("migration") }
  let(:dsl) { Mobilis::DSL::DSLContext.new(system) }

  def realize
    Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
  end

  it "loads legacy name-only dependencies" do
    api = dsl.rack("api")
    db = dsl.postgres("store")
    raw = system.to_h
    raw[:nodes].first[:extra_depends_on] = [db.name]
    loaded = Mobilis::System.from_h(raw)
    expect(loaded[api.id].extra_depends_on.first[:target]).to eq(loaded[db.id])
  end
end
