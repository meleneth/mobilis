# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Rails do
  let(:realized_env) { build(:realized_env, :with_rails_and_postgres) }
  let(:realized_rails_node) { realized_env.find_node_by_name("rails") }

  it "sets service directory and data volume flags" do
    pp realized_env
    expect(realized_rails_node.has_service_dir).to be true
    expect(realized_rails_node.has_data_volume).to be false
  end

  it "registers a DATABASE_URL referencing the primary database" do
    env_db_url = realized_rails_node.env_db_url
    expect(env_db_url.resolved_name).to eq("DATABASE_URL")
    expect(env_db_url.specific_name).to eq("USERDB_DATABASE_URL")
    expect(env_db_url.value).to eq("DATABASE_URL")
  end
end
