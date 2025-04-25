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
      rails_realized_node = realized_env.node_by_name("user")
    end
  end
  describe "#depends_on_overrides_for" do
    subject(:manifest) { build(:manifest, :with_rails_and_postgres) }
    it "returns the correct value" do
      realized_env = manifest.realized_env(:production)
      expect(manifest.depends_on_overrides_for(realized_env)).to eq({ services: { "user" => {

                                                                      depends_on: {
                                                                        "userdb" => {
                                                                          condition: "service_healthy",
                                                                          restart: true
                                                                        },
                                                                        "userdb-cache" => {
                                                                          condition: "service_healthy",
                                                                          restart: true
                                                                        },
                                                                        "userdb-cable" => {
                                                                          condition: "service_healthy",
                                                                          restart: true
                                                                        },
                                                                        "userdb-queue" => {
                                                                          condition: "service_healthy",
                                                                          restart: true
                                                                        }
                                                                      }

                                                                    } } })
    end
  end
end
