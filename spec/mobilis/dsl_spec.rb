# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::DSL::DSLContext do
  let(:system) { Mobilis::System.new("generate") }
  subject(:context) { described_class.new(system) }

  it "adds MySQL nodes by name" do
    node = context.mysql("user-db")

    expect(node).to be_a(Mobilis::Node::MySQL)
    expect(context.named("user-db")).to eq(node)
    expect(system.config_nodes.values).to include(node)
  end

  it "supports declaring PostgreSQL replication from a postgres block" do
    primary = context.postgres("primary-db")
    replica = context.postgres("replica-db") do |db|
      db.replicate_from(primary)
    end

    expect(replica.replicate_from).to eq(primary)
  end

  it "adds pgAdmin nodes with PostgreSQL database connections" do
    database = context.postgres("user-db")
    node = context.pgadmin("pgadmin", databases: [database])

    expect(node).to be_a(Mobilis::Node::Pgadmin)
    expect(node.databases).to eq([database])
    expect(context.named("pgadmin")).to eq(node)
  end
end
