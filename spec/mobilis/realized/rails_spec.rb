# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::Rails do
  let(:pg_node) { build(:postgres_node, name: "userdb") }
  let(:rails_node) { build(:rails_node, name: "myapp", primary_database: pg_node) }

  let(:system) { build(:system, nodes: [pg_node, rails_node]) }
  let(:env) { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }

  let(:realized_pg) { Mobilis::Realized::PostgreSQL.new(env, pg_node, external_port_no: 15_432) }
  subject(:realized_rails) { described_class.new(env, rails_node) }

  before do
    env << realized_pg
    env << realized_rails
  end

  it "sets service directory and data volume flags" do
    expect(realized_rails.has_service_dir).to be true
    expect(realized_rails.has_data_volume).to be false
  end

  it "registers a DATABASE_URL referencing the primary database" do
    env_var = realized_rails.env_vars.find { |v| v.specific_name == "DATABASE_URL" }
    expect(env_var).not_to be_nil
    expect(env_var.value).to eq("${USERDB_POSTGRES_URL}")
    expect(env_var.resolved_name).to eq("MYAPP_DATABASE_URL")
  end
end
