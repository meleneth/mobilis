# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Prometheus do
  let(:realized_env) { build(:realized_env, :with_otel) }
  let(:prometheus_node) { realized_env.find_realized_node_by_name("prometheus") }

  before do
    prometheus_node.populate_compose_depends_on
  end

  it "sets service directory and data volume flags" do
    expect(prometheus_node.has_service_dir).to be true
    expect(prometheus_node.has_data_volume).to be false
    expect(prometheus_node.has_dockerfile).to be false
  end

  it "#compose" do
    expect(prometheus_node.compose.clean_shrunk).to eq({ image: "prom/prometheus:v3.4.1" })
  end
end
