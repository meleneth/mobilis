# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::RealizedEnv do
  let(:system_postgres_node) { build(:postgres_node, name: "test-db") }
  let(:system_rails_node) { build(:rails_node, primary_database: system_postgres_node) }
  let(:system) { build(:system, nodes: [system_postgres_node, system_rails_node]) }
  let(:execution_environment) { Mobilis::ExecutionEnvironment.new(:test) }

  subject(:realized_env) { described_class.new(system, execution_environment) }

  describe "initialization" do
    it "initializes with a Mobilis::System and ExecutionEnvironment" do
      expect(realized_env.system).to eq(system)
      expect(realized_env.environment).to eq(execution_environment)
    end

    it "generates RealizedNode instances for each node in system" do
      expect(realized_env.realized_nodes.count).to eq(system.config_nodes.count)
      expect(realized_env.realized_nodes).to all(be_a(Mobilis::Base::RealizedNode))
    end

    it "maintains relationships between realized nodes" do
      rails_node = realized_env.realized_nodes.find { |n| n.is_a?(Mobilis::Realized::Rails) }
      postgres_node = realized_env.realized_nodes.find { |n| n.is_a?(Mobilis::Realized::PostgreSQL) }

      expect(rails_node.primary_database).to eq(postgres_node)
    end
  end

  describe "#realized_nodes" do
    it "returns an array of realized node instances" do
      expect(realized_env.realized_nodes).to be_an(Array)
      expect(realized_env.realized_nodes).to all(satisfy { |realized_node|
        realized_node.is_a?(Mobilis::Base::RealizedNode)
      })
    end
  end

  describe "#find_node_by_name" do
    let(:node_name) { "test-db" }

    it "returns the corresponding realized node" do
      result = realized_env.find_realized_node_by_name(node_name)
      expect(result).to be_a(Mobilis::Base::RealizedNode)
      expect(result.config_node.name).to eq(node_name)
    end

    it "returns nil if no matching node exists" do
      expect(realized_env.find_realized_node_by_name("nonexistent")).to be_nil
    end
  end

  describe "environment-scoped values" do
    it "uses ExecutionEnvironment#to_s for environment-specific names" do
      postgres_node = realized_env.realized_nodes.find { |n| n.is_a?(Mobilis::Realized::PostgreSQL) }
      expect(postgres_node.envfile_vars.data.any? { |var| var.value.include?("test") }).to be(true)
    end
  end

  describe "#node_for" do
    let(:system_node) { system.each_config_node.first }

    it "returns the corresponding realized node for a given system node" do
      realized_node = realized_env.realized_node_for_config_node(system_node)
      expect(realized_node).to be_a(Mobilis::Base::RealizedNode)
      expect(realized_node.config_node).to eq(system_node)
    end

    it "returns nil if there is no matching realized node" do
      nonexistent_system_node = double("nonexistent_node")
      expect(realized_env.realized_node_for_config_node(nonexistent_system_node)).to be_nil
    end
  end
end
