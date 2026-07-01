# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Grafana do
  let(:realized_env) { build(:realized_env, :with_otel) }
  let(:grafana_node) { realized_env.find_realized_node_by_name("grafana") }

  before do
    grafana_node.populate_compose_depends_on
  end

  it "sets service directory and data volume flags" do
    expect(grafana_node.has_service_dir).to be true
    expect(grafana_node.has_data_volume).to be true
    expect(grafana_node.has_dockerfile).to be false
  end

  it "#compose" do
    expect(grafana_node.compose.clean_shrunk).to eq(
      { image: "grafana/grafana:13.1.0",
        ports: ["${GRAFANA_WEB_PORT}:3000"],
        environment: [
          "GF_PATHS_PROVISIONING=/etc/grafana/provisioning",
          "GF_SECURITY_ADMIN_PASSWORD=mobilis-admin",
          "GF_SECURITY_ADMIN_USER=admin",
          "LOKI_URL=${GRAFANA__LOKI_URL}",
          "PROMETHEUS_URL=${GRAFANA__PROMETHEUS_URL}"
        ],
        volumes: [
          "./data/test/grafana:/var/lib/grafana",
          "./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources"
        ],
        user: "${HOST_UID}:${HOST_GID}",
        depends_on: {
          loki: {
            condition: "service_started"
          },
          prometheus: {
            condition: "service_started",
            restart: true
          }
        } }
    )
  end
end
