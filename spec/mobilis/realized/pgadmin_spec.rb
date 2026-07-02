# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Pgadmin do
  let(:realized_env) { build(:realized_env, system_traits: [:with_pgadmin_and_postgres]) }
  let(:pgadmin) { realized_env.find_realized_node_by_name("pgadmin") }

  it "sets service directory and no data volume" do
    expect(pgadmin.has_service_dir).to be true
    expect(pgadmin.has_data_volume).to be false
    expect(pgadmin.has_dockerfile).to be false
  end

  it "exposes the pgAdmin web port" do
    expect(pgadmin.exposed_port_no).to eq(80)
  end

  it "configures pgAdmin and depends on PostgreSQL" do
    expect(pgadmin.compose.clean_shrunk).to eq(
      image: "dpage/pgadmin4:9.16",
      ports: ["${PGADMIN_WEB_PORT}:80"],
      environment: [
        "PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=False",
          "PGADMIN_DEFAULT_EMAIL=admin@example.com",
        "PGADMIN_DEFAULT_PASSWORD=mobilis-admin",
        "PGADMIN_DISABLE_POSTFIX=True",
        "PGADMIN_REPLACE_SERVERS_ON_STARTUP=True"
      ],
      volumes: [
        "./pgadmin/servers.json:/pgadmin4/servers.json"
      ],
      depends_on: {
        userdb: {
          condition: "service_healthy",
          restart: true
        }
      }
    )
  end
end
