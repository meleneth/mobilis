# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::OtelCollector do
  let(:realized_env) { build(:realized_env, :with_otel) }
  let(:otel_collector_node) { realized_env.find_realized_node_by_name("otel-collector") }

  before do
    otel_collector_node.populate_compose_depends_on
  end

  it "sets service directory and data volume flags" do
    expect(otel_collector_node.has_service_dir).to be true
    expect(otel_collector_node.has_data_volume).to be false
    expect(otel_collector_node.has_dockerfile).to be false
  end

  it "#compose" do
    expect(otel_collector_node.compose.clean_shrunk).to eq(
      { image: "otel/opentelemetry-collector-contrib:latest",
        ports: [
          "${OTEL_COLLECTOR_COLLECTOR_PORT}:4318"
        ],
        volumes: [
          "./otel-collector/otel-collector-config.yaml:/etc/otel-collector-config.yaml"
        ],
        command: ["--config=/etc/otel-collector-config.yaml"],
        depends_on: {
          jaeger: {
            condition: "service_started",
            restart: true
          }
        } }
    )
  end
end
