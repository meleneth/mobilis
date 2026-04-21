# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Jaeger do
  let(:realized_env) { build(:realized_env, :with_otel) }
  let(:jaeger_node) { realized_env.find_realized_node_by_name("jaeger") }

  before do
    jaeger_node.populate_compose_depends_on
  end

  it "sets service directory and data volume flags" do
    expect(jaeger_node.has_service_dir).to be false
    expect(jaeger_node.has_data_volume).to be false
    expect(jaeger_node.has_dockerfile).to be false
  end

  it "has correct jaeger_endpoint value" do
    expect(jaeger_node.jaeger_endpoint).to eq("jaeger:4317")
  end

  it "#compose" do
    expect(jaeger_node.compose.clean_shrunk).to eq(
      { image: "jaegertracing/jaeger:2.17.0", ports: [
        "${JAEGER_WEB_PORT}:16686"
      ] }
    )
  end
end
