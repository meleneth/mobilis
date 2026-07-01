# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Alloy do
  let(:realized_env) { build(:realized_env, :with_otel) }
  let(:alloy_node) { realized_env.find_realized_node_by_name("alloy") }

  it "sets service directory and data volume flags" do
    expect(alloy_node.has_service_dir).to be true
    expect(alloy_node.has_data_volume).to be false
    expect(alloy_node.has_dockerfile).to be false
  end

  it "#compose" do
    expect(alloy_node.compose.clean_shrunk).to eq(
      {
        image: "grafana/alloy:latest",
        volumes: [
          "./alloy/config.alloy:/etc/alloy/config.alloy",
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ],
        command: [
          "run",
          "/etc/alloy/config.alloy",
          "--server.http.listen-addr=0.0.0.0:12345",
          "--storage.path=/var/lib/alloy/data"
        ],
        depends_on: {
          loki: {
            condition: "service_started"
          }
        }
      }
    )
  end
end
