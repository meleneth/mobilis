# frozen_string_literal: true

RSpec.describe Mobilis::Manifest do
  subject(:manifest) { build(:manifest, :with_rails_and_postgres, :suppress_plugins) }

  describe "#realized_env" do
    it "finds the correct realized env..." do
      realized_env = manifest.realized_env(:test)
      expect(realized_env.to_s).to eq("test")
    end
    it "... which has a rails realized node" do
      realized_env = manifest.realized_env(:test)
      rails_realized_node = realized_env.realized_node_by_name("user")
    end
  end
  describe "#overrides_for" do
    subject(:manifest) { build(:manifest, :with_rails_and_postgres) }
    let(:production_realized_env) { manifest.realized_env(:production) }
    let(:production_rails_realized_node) { production_realized_env.realized_node_by_name("user") }
    let(:plugin) { Mobilis::Plugin::RailsDBFanoutRealizedNode.new(manifest, production_rails_realized_node) }

    xit "returns the correct value" do
      realized_env = manifest.realized_env(:production)
      expected = {
        services: {
          user: {
            depends_on: {
              userdb: { condition: "service_healthy", restart: true },
              "userdb-cache": { condition:  "service_healthy", restart: true },
              "userdb-cable": { condition:  "service_healthy", restart: true },
              "userdb-queue": { condition:  "service_healthy", restart: true }
            },
            environment: [
              "DATABASE_URL=${USERDB_DATABASE_URL}",
              "RAILS_ENV=production",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
              "CACHE_DATABASE_URL=${USERDB_CACHE_DATABASE_URL}",
              "CABLE_DATABASE_URL=${USERDB_CABLE_DATABASE_URL}",
              "QUEUE_DATABASE_URL=${USERDB_QUEUE_DATABASE_URL}"
            ]
          }
        }
      }

      expect(manifest.overrides_for(realized_env)).to eq(expected)
    end
  end
  describe "#overrides_for" do
    subject(:manifest) { build(:manifest, :with_two_rails_and_postgres) }
    xit "returns the correct value" do
      realized_env = manifest.realized_env(:production)
      expected = { services:
        { user:
          {
            environment: [
              "DATABASE_URL=${USERDB_DATABASE_URL}",
              "RAILS_ENV=production",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
              "CACHE_DATABASE_URL=${USERDB_CACHE_DATABASE_URL}",
              "CABLE_DATABASE_URL=${USERDB_CABLE_DATABASE_URL}",
              "QUEUE_DATABASE_URL=${USERDB_QUEUE_DATABASE_URL}"
            ],
            depends_on: {
              userdb: {
                condition: "service_healthy",
                restart: true
              },
              "userdb-cache": {
                condition: "service_healthy",
                restart: true
              },
              "userdb-cable": {
                condition: "service_healthy",
                restart: true
              },
              "userdb-queue": {
                condition: "service_healthy",
                restart: true
              }
            }
          },
          account: {
            environment: [
              "DATABASE_URL=${ACCOUNTDB_DATABASE_URL}",
              "RAILS_ENV=production",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
              "CACHE_DATABASE_URL=${ACCOUNTDB_CACHE_DATABASE_URL}",
              "CABLE_DATABASE_URL=${ACCOUNTDB_CABLE_DATABASE_URL}",
              "QUEUE_DATABASE_URL=${ACCOUNTDB_QUEUE_DATABASE_URL}"
            ],
            depends_on: {
              accountdb: {
                condition: "service_healthy",
                restart: true
              },
              "accountdb-cache": {
                condition: "service_healthy",
                restart: true
              },
              "accountdb-cable": {
                condition: "service_healthy",
                restart: true
              },
              "accountdb-queue": {
                condition: "service_healthy",
                restart: true
              },
              user: {
                condition: "service_started",
                restart: false
              }
            }
          } } }
      expect(manifest.overrides_for(realized_env)).to eq(expected)

      #      expect(manifest.compose["services"]["user"]["depends_on"]).to include("userdb")
      #      expect(manifest.compose["services"]["account"]["depends_on"]).to include("user", "accountdb")
    end
  end
end
