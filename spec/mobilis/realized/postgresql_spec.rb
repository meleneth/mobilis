# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::PostgreSQL do
  let(:postgres_node) { build(:postgres_node, name: "userdb") }
  let(:system)        { build(:system, nodes: [postgres_node]) }
  let(:env)           { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }

  subject(:realized_pg) do
    described_class.new(env, postgres_node)
  end

  it "uses fixed internal port" do
    expect(realized_pg.internal_port_no).to eq(5432)
  end

  it "sets data volume and service directory flags" do
    expect(realized_pg.has_data_volume).to be true
    expect(realized_pg.has_service_dir).to be false
  end

  it "produces a single PortMap with a memo" do
    expect(realized_pg.compose_ports.data.size).to eq(1)
    port = realized_pg.compose_ports.data.first
    expect(port.external_port_no).to eq("${USERDB_POSTGRES_PORT}")
    expect(port.internal_port_no).to eq(5432)
    expect(port.memo).to match(/userdb database port/)
  end

  it "constructs environment variables using EnvVar - specific_name" do
    keys = realized_pg.compose_environment.data.to_a.map(&:compose_repr)
    expect(keys).to eq([
                         "POSTGRES_USER=${USERDB_POSTGRES_USER}",
                         "POSTGRES_PASSWORD=${USERDB_POSTGRES_PASSWORD}",
                         "POSTGRES_DB=${USERDB_POSTGRES_DB}"
                       ])
  end
  it "constructs per-environment variables including data dir" do
    Mobilis::Base::RealizedNode.class_variable_set(:@@next_port_no, 42_069)

    keys = subject.envfile_vars.data.map(&:env_repr)
    expect(keys).to eq([
                         "USERDB_DATABASE_URL=postgres://userdb-test-user:userdb-test-password@userdb:5432/userdb_test",
                         "USERDB_POSTGRES_USER=userdb-test-user",
                         "USERDB_POSTGRES_PASSWORD=userdb-test-password",
                         "USERDB_POSTGRES_DB=userdb_test",
                         "USERDB_POSTGRES_PORT=42079",
                         "USERDB_POSTGRES_DATA=./data/test/userdb"
                       ])
  end
  it "constructs environment variables using EnvVar - realized_name" do
    keys = realized_pg.compose_environment.data.to_a.map(&:compose_repr)
    expect(keys).to eq([
                         "POSTGRES_USER=${USERDB_POSTGRES_USER}",
                         "POSTGRES_PASSWORD=${USERDB_POSTGRES_PASSWORD}",
                         "POSTGRES_DB=${USERDB_POSTGRES_DB}"
                       ])
  end

  it "#has_healthcheck?" do
    expect(realized_pg.has_healthcheck?).to be_truthy
  end

  it "#dependant_services_require_restart?" do
    expect(realized_pg.dependant_services_require_restart?).to be_truthy
  end

  it "#compose" do
    expected = {
      image: "postgres:18.3-trixie",
      ports: [
        "${USERDB_POSTGRES_PORT}:5432"
      ],
      environment: [
        "POSTGRES_DB=${USERDB_POSTGRES_DB}",
        "POSTGRES_PASSWORD=${USERDB_POSTGRES_PASSWORD}",
        "POSTGRES_USER=${USERDB_POSTGRES_USER}"
      ],
      volumes: [
        "${USERDB_POSTGRES_DATA}:/var/lib/postgresql"
      ],
      healthcheck: {
        test: [
          "CMD-SHELL",
          "pg_isready -U ${USERDB_POSTGRES_USER} -d ${USERDB_POSTGRES_DB}"
        ],
        interval: "10s",
        timeout: "5s",
        retries: 5,
        start_period: "5s"
      }
    }
    expect(realized_pg.compose.clean_shrunk).to eq(expected)
  end

  context "with replication" do
    let(:primary_node) { build(:postgres_node, name: "primary-db") }
    let(:replica_node) do
      node = build(:postgres_node, name: "replica-db")
      node.replicate_from(primary_node)
      node
    end
    let(:system) { build(:system, nodes: [primary_node, replica_node]) }
    let(:env) { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }
    let(:primary) { env.find_realized_node_by_name("primary-db") }
    let(:replica) { env.find_realized_node_by_name("replica-db") }

    it "marks the primary and replica as service-dir backed" do
      expect(primary.has_service_dir).to be true
      expect(replica.has_service_dir).to be true
    end

    it "configures the primary for streaming replication" do
      compose = primary.compose.clean_shrunk

      expect(compose[:command]).to include(
        "postgres",
        "wal_level=replica",
        "max_wal_senders=10",
        "max_replication_slots=10"
      )
      expect(compose[:environment]).to include(
        "POSTGRES_REPLICATION_USER=${PRIMARY_DB_POSTGRES_REPLICATION_USER}",
        "POSTGRES_REPLICATION_PASSWORD=${PRIMARY_DB_POSTGRES_REPLICATION_PASSWORD}"
      )
      expect(compose[:volumes]).to include(
        "./primary-db/init-replication-primary.sh:/docker-entrypoint-initdb.d/010-init-replication-primary.sh"
      )
    end

    it "configures the replica to clone from the primary" do
      compose = replica.compose.clean_shrunk

      expect(replica.url).to eq("postgres://primary-db-test-user:primary-db-test-password@replica-db:5432/primary-db_test")
      expect(compose[:entrypoint]).to eq(["mobilis-postgres-replica-entrypoint.sh"])
      expect(compose[:command]).to eq(["postgres"])
      expect(compose[:depends_on]).to eq(
        :"primary-db" => {
          condition: "service_healthy",
          restart: true
        }
      )
      expect(compose[:environment]).to include(
        "POSTGRES_DB=${REPLICA_DB_POSTGRES_DB}",
        "POSTGRES_PASSWORD=${REPLICA_DB_POSTGRES_PASSWORD}",
        "POSTGRES_PRIMARY_HOST=${REPLICA_DB_POSTGRES_PRIMARY_HOST}",
        "POSTGRES_PRIMARY_PORT=${REPLICA_DB_POSTGRES_PRIMARY_PORT}",
        "POSTGRES_REPLICATION_USER=${REPLICA_DB_POSTGRES_REPLICATION_USER}",
        "POSTGRES_REPLICATION_PASSWORD=${REPLICA_DB_POSTGRES_REPLICATION_PASSWORD}",
        "POSTGRES_USER=${REPLICA_DB_POSTGRES_USER}"
      )
      expect(replica.envfile_vars.data.map(&:env_repr)).to include(
        "REPLICA_DB_DATABASE_URL=postgres://primary-db-test-user:primary-db-test-password@replica-db:5432/primary-db_test",
        "REPLICA_DB_POSTGRES_USER=primary-db-test-user",
        "REPLICA_DB_POSTGRES_PASSWORD=primary-db-test-password",
        "REPLICA_DB_POSTGRES_DB=primary-db_test"
      )
      expect(compose[:volumes]).to include(
        "./replica-db/replica-entrypoint.sh:/usr/local/bin/mobilis-postgres-replica-entrypoint.sh"
      )
    end
  end
end
