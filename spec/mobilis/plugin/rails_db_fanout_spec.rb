# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Plugin::RailsDBFanout do
  let(:manifest) { build(:manifest, :suppress_plugins, :with_rails_and_postgres) }

  subject(:plugin) { Mobilis::Plugin::RailsDBFanout.new(manifest) }

  describe "initialization" do
    it "initializes with a Mobilis::System and ExecutionEnvironment" do
      plugin.hook_envs_realized
      realized_rails_node = manifest.realized_env(:test).node_by_name("user")
      expect(realized_rails_node.instance_of?(Mobilis::Realized::Rails)).to eq(true)
    end
    it "sets DATABASE_URL on the rails container" do
      # err, this plugin doesn't actually do this? TODO FIXME MAYBE (here's my number)
      realized_rails_node = manifest.realized_env(:test).node_by_name("user")
      expect(realized_rails_node.env_var_resolved("DATABASE_URL").specific_name).to eq("USERDB_DATABASE_URL")
    end
    it "sets CACHE_DATABASE_URL on the rails container" do
      plugin.hook_envs_realized
      realized_rails_node = manifest.realized_env(:production).node_by_name("user")
      expect(realized_rails_node.env_var_resolved("CACHE_DATABASE_URL").specific_name).to eq("USERDB_CACHE_DATABASE_URL")
    end
    it "sets CABLE_DATABASE_URL on the rails container" do
      plugin.hook_envs_realized
      realized_rails_node = manifest.realized_env(:production).node_by_name("user")
      expect(realized_rails_node.env_var_resolved("CABLE_DATABASE_URL").specific_name).to eq("USERDB_CABLE_DATABASE_URL")
    end
    it "sets QUEUE_DATABASE_URL on the rails container" do
      plugin.hook_envs_realized
      realized_rails_node = manifest.realized_env(:production).node_by_name("user")
      expect(realized_rails_node.env_var_resolved("QUEUE_DATABASE_URL").specific_name).to eq("USERDB_QUEUE_DATABASE_URL")
    end
  end
end
