# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Mobilis::ServiceWriter::PostgreSQL do
  let(:primary_node) { build(:postgres_node, name: "primary-db") }
  let(:replica_node) do
    node = build(:postgres_node, name: "replica-db")
    node.replicate_from(primary_node)
    node
  end
  let(:system) { build(:system, nodes: [primary_node, replica_node]) }
  let(:env) { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }

  it "writes primary replication bootstrap script" do
    primary = env.find_realized_node_by_name("primary-db")

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        described_class.new(nil, env, primary).write

        script = File.read("init-replication-primary.sh")
        expect(script).to include("host replication ${POSTGRES_REPLICATION_USER} all scram-sha-256")
        expect(script).to include("CREATE ROLE \"${POSTGRES_REPLICATION_USER}\" WITH REPLICATION LOGIN PASSWORD")
      end
    end
  end

  it "writes replica base-backup entrypoint" do
    replica = env.find_realized_node_by_name("replica-db")

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        described_class.new(nil, env, replica).write

        script = File.read("replica-entrypoint.sh")
        expect(script).to include("pg_basebackup")
        expect(script).to include("chown -R postgres:postgres /var/lib/postgresql")
        expect(script).to include("-h \"$POSTGRES_PRIMARY_HOST\"")
        expect(script).to include("exec docker-entrypoint.sh \"$@\"")
      end
    end
  end
end
