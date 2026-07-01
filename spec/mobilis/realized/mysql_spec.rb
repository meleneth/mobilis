# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Realized::MySQL do
  let(:mysql_node) { build(:mysql_node, name: "userdb") }
  let(:system)     { build(:system, nodes: [mysql_node]) }
  let(:env)        { Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new("test")) }

  subject(:realized_mysql) do
    described_class.new(env, mysql_node)
  end

  it "uses fixed internal port" do
    expect(realized_mysql.internal_port_no).to eq(3306)
  end

  it "sets data volume and service directory flags" do
    expect(realized_mysql.has_data_volume).to be true
    expect(realized_mysql.has_service_dir).to be false
  end

  it "constructs per-environment variables including data dir" do
    Mobilis::Base::RealizedNode.class_variable_set(:@@next_port_no, 42_069)

    keys = realized_mysql.envfile_vars.data.map(&:env_repr)
    expect(keys).to eq([
                         "USERDB_DATABASE_URL=mysql2://userdb-test-user:userdb-test-password@userdb:3306/userdb_test",
                         "USERDB_MYSQL_USER=userdb-test-user",
                         "USERDB_MYSQL_PASSWORD=userdb-test-password",
                         "USERDB_MYSQL_DATABASE=userdb_test",
                         "USERDB_MYSQL_ROOT_PASSWORD=userdb-test-root-password",
                         "USERDB_MYSQL_PORT=42079",
                         "USERDB_MYSQL_DATA=./data/test/userdb"
                       ])
  end

  it "provides Rails db package support" do
    expect(realized_mysql.build_packages).to eq(["default-libmysqlclient-dev"])
    expect(realized_mysql.runtime_packages).to eq(["libmariadb3"])
    expect(realized_mysql.additional_gems).to eq(["mysql2"])
  end

  it "#compose" do
    expected = {
      image: "mysql:9.3.0",
      ports: [
        "${USERDB_MYSQL_PORT}:3306"
      ],
      environment: [
        "MYSQL_DATABASE=${USERDB_MYSQL_DATABASE}",
        "MYSQL_PASSWORD=${USERDB_MYSQL_PASSWORD}",
        "MYSQL_ROOT_PASSWORD=${USERDB_MYSQL_ROOT_PASSWORD}",
        "MYSQL_USER=${USERDB_MYSQL_USER}"
      ],
      volumes: [
        "${USERDB_MYSQL_DATA}:/var/lib/mysql"
      ],
      healthcheck: {
        test: [
          "CMD-SHELL",
          "mysqladmin ping -h 127.0.0.1 -u${USERDB_MYSQL_USER} -p${USERDB_MYSQL_PASSWORD}"
        ],
        interval: "10s",
        timeout: "5s",
        retries: 5,
        start_period: "5s"
      }
    }
    expect(realized_mysql.compose.clean_shrunk).to eq(expected)
  end
end
