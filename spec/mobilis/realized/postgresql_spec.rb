# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::PostgreSQL do
  let(:postgres_node) { build(:postgres_node, name: "userdb") }
  let(:system)        { build(:system, nodes: [postgres_node]) }
  let(:env)           { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }

  subject(:realized_pg) do
    described_class.new(env, postgres_node, external_port_no: 15_432)
  end

  it "uses fixed internal port" do
    expect(realized_pg.internal_port_no).to eq(5432)
  end

  it "sets data volume and service directory flags" do
    expect(realized_pg.has_data_volume).to be true
    expect(realized_pg.has_service_dir).to be false
  end

  it "produces a single PortMap with a memo" do
    expect(realized_pg.port_maps.size).to eq(1)
    port = realized_pg.port_maps.first
    expect(port.external_port_no).to eq(15_432)
    expect(port.internal_port_no).to eq(5432)
    expect(port.memo).to match(/PostgreSQL/)
  end

  it "constructs environment variables using EnvVar" do
    keys = realized_pg.env_vars.map(&:resolved_name)
    expect(keys).to include(
      "USERDB_POSTGRES_DB",
      "USERDB_POSTGRES_USER",
      "USERDB_POSTGRES_PASSWORD"
    )
  end

  it "constructs the expected URL" do
    expect(realized_pg.url).to eq(
      "postgres://userdb-test-user:userdb-test-password@userdb:5432/userdb_test"
    )
  end

  it "#env_db_url" do
    expect(realized_pg.env_db_url.resolved_name).to eq("")
    expect(realized_pg.env_db_url.specific_name).to eq("USERDB_DATABASE_URL")
    expect(realized_pg.env_db_url.value).to eq("postgres://userdb-test-user:userdb-test-password@userdb:5432/userdb_test")
  end
end
