# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Promtail do
  let(:realized_env) { build(:realized_env, :with_otel) }
  let(:promtail_node) { realized_env.find_realized_node_by_name("promtail") }

  it "sets service directory and data volume flags" do
    expect(promtail_node.has_service_dir).to be true
    expect(promtail_node.has_data_volume).to be false
    expect(promtail_node.has_dockerfile).to be false
  end

  it "#compose" do
    expect(promtail_node.compose.clean_shrunk).to eq(
      {
        image: "grafana/promtail:3.6.8",
        volumes: [
          "./promtail/promtail-config.yaml:/etc/promtail/promtail-config.yaml",
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ],
        depends_on: {
          loki: {
            condition: "service_started"
          }
        },
        command: ["-config.file=/etc/promtail/promtail-config.yaml"]
      }
    )
  end
end
