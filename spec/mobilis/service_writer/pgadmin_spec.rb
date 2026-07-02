# frozen_string_literal: true

require "json"
require "spec_helper"
require "tmpdir"

RSpec.describe Mobilis::ServiceWriter::Pgadmin do
  let(:realized_env) { build(:realized_env, system_traits: [:with_pgadmin_and_postgres]) }
  let(:pgadmin) { realized_env.find_realized_node_by_name("pgadmin") }

  it "writes servers.json for connected PostgreSQL databases" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        described_class.new(nil, realized_env, pgadmin).write

        json = JSON.parse(File.read("servers.json"))
        expect(json).to eq(
          "Servers" => {
            "1" => {
              "Name" => "userdb",
              "Group" => "test",
              "Host" => "userdb",
              "Port" => 5432,
              "MaintenanceDB" => "userdb_test",
              "Username" => "userdb-test-user",
              "SSLMode" => "prefer",
              "PasswordExecCommand" => "printf '%s' 'userdb-test-password'"
            }
          }
        )
      end
    end
  end
end
