# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Rack do
  let(:rack_node) { build(:rack_node, name: "playerservice", instances: 3) }
  let(:system) { build(:system, nodes: [rack_node]) }
  let(:env) { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }
  let(:realized_rack) { env.find_realized_node_by_name("playerservice") }

  it "uses the project root build context for local gem support" do
    expect(realized_rack.compose.clean_shrunk).to include(
      build: {
        context: "./",
        dockerfile: "./playerservice/Dockerfile"
      }
    )
  end

  it "expands instances into additional compose services" do
    services = realized_rack.service_wrapped_compose.fetch(:services)

    expect(services.keys).to eq(["playerservice", "player2service", "player3service"])
    expect(services.fetch("player2service")).not_to have_key(:ports)
  end

  it "recognizes otel collector dependencies after realization" do
    collector = build(:otel_collector_node, name: "otel-collector")
    rack_node.has_extra_depends_on(collector)
    system << collector

    expect(realized_rack.otel_enabled?).to be true
  end
end
