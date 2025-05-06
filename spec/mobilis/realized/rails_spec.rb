# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Rails do
  let(:realized_env) { build(:realized_env, :with_rails_and_postgres) }
  let(:realized_rails_node) { realized_env.find_realized_node_by_name("user") }

  before do
    realized_rails_node.populate_compose_depends_on
  end

  it "sets service directory and data volume flags" do
    expect(realized_rails_node.has_service_dir).to be true
    expect(realized_rails_node.has_data_volume).to be false
  end

  it "registers a DATABASE_URL referencing the primary database" do
    env_db_url = realized_rails_node.env_db_url
    expect(env_db_url.container_name).to eq("DATABASE_URL")
    expect(env_db_url.envfile_name).to eq("USERDB_DATABASE_URL")
    expect(env_db_url.value).to eq("postgres://userdb-test-user:userdb-test-password@userdb:5432/userdb_test")
  end

  it "#compose" do
    expect(realized_rails_node.compose.clean_shrunk).to eq(
      { image: "generate/user",
        environment: [
          "DATABASE_URL=${USERDB_DATABASE_URL}",
          "RAILS_ENV=test",
          "RAILS_MIN_THREADS=5",
          "RAILS_MAX_THREADS=5"
        ],
        build: { context: "./user" },
        depends_on: {
          userdb: { condition: "service_healthy", restart: true }
        } }
    )
  end
end
