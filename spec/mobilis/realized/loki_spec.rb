# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Loki do
  let(:realized_env) { build(:realized_env, :with_otel) }
  let(:loki_node) { realized_env.find_realized_node_by_name("loki") }

  it "sets service directory and data volume flags" do
    expect(loki_node.has_service_dir).to be true
    expect(loki_node.has_data_volume).to be false
    expect(loki_node.has_dockerfile).to be false
  end

  it "#compose" do
    expect(loki_node.compose.clean_shrunk).to eq(
      {
        image: "grafana/loki:3.7.3",
        ports: ["${LOKI_WEB_PORT}:3100"],
        volumes: ["./loki/loki-config.yaml:/etc/loki/loki-config.yaml"],
        command: ["-config.file=/etc/loki/loki-config.yaml"]
      }
    )
  end
end
