# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Plugin::RailsDBFanoutRealizedNode do
  let(:manifest) { build(:manifest, :suppress_plugins, :with_rails_and_postgres) }
  let(:production_realized_env) { manifest.realized_env(:production) }
  let(:production_rails_realized_node) { production_realized_env.realized_node_by_name("user") }
  let(:compose_overrides) { production_rails_realized_node.compose_overrides.symbolize_keys_deep }
  let(:override_env_vars) { compose_overrides[:environment] }

  subject(:plugin) { Mobilis::Plugin::RailsDBFanoutRealizedNode.new(manifest, production_rails_realized_node) }

  before do
    production_rails_realized_node.populate_compose_depends_on
    plugin.create_additional_services
  end

  describe "initialization" do
    it "initializes with a Mobilis::System and ExecutionEnvironment" do
      expect(production_rails_realized_node.instance_of?(Mobilis::Realized::Rails)).to eq(true)
    end
    it "sets DATABASE_URL on the rails container" do
      # err, this plugin doesn't actually do this? TODO FIXME MAYBE (here's my number)
      production_rails_realized_node
      expect(override_env_vars).to include("DATABASE_URL=${USERDB_DATABASE_URL}")
    end
    it "sets CACHE_DATABASE_URL on the rails container" do
      expect(override_env_vars).to include("CACHE_DATABASE_URL=${USERDB_CACHE_DATABASE_URL}")
    end
    it "sets CABLE_DATABASE_URL on the rails container" do
      expect(override_env_vars).to include("CABLE_DATABASE_URL=${USERDB_CABLE_DATABASE_URL}")
    end
    it "sets QUEUE_DATABASE_URL on the rails container" do
      expect(override_env_vars).to include("QUEUE_DATABASE_URL=${USERDB_QUEUE_DATABASE_URL}")
    end
    it "sets up compose_overrides in production" do
      expected = {
        userdb: { condition: "service_healthy", restart: true },
        "userdb-cache": { condition:  "service_healthy", restart: true },
        "userdb-cable": { condition:  "service_healthy", restart: true },
        "userdb-queue": { condition:  "service_healthy", restart: true }
      }

      expect(production_rails_realized_node.compose_depends_on_overrides.as_json).to eq(expected)
    end
  end
end
