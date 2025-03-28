# frozen_string_literal: true

RSpec.describe Mobilis::OutputFiles::Env do
  let(:metaproject) { build(:metaproject) }

  describe "development.env" do
    let(:expected) do
      <<~ENVFILE
        CACHE_EXTERNAL_PORT_NO=10100
        CACHE_INTERNAL_PORT_NO=9292
        ENVIRONMENT=test
        RUNASUSER=1000:1000
        SOMERACK_EXTERNAL_PORT_NO=10200
        SOMERACK_INTERNAL_PORT_NO=9292
        TESTM_DB_EXTERNAL_PORT_NO=10300
        TESTM_DB_INTERNAL_PORT_NO=3306
        TESTM_DB_MYSQL_DATA=./data/test/testm-db
        TESTM_DB_MYSQL_PASSWORD=testm-db_password
        TESTM_DB_MYSQL_URL=mysql2://testm-db:testm-db_password@testm-db:3306/?pool=5
        TESTM_DB_MYSQL_USER=testm-db
        TESTPDB_EXTERNAL_PORT_NO=10400
        TESTPDB_INTERNAL_PORT_NO=5432
        TESTPDB_POSTGRES_DATA=./data/test/testp-db
        TESTPDB_POSTGRES_DB=testp-db-test
        TESTPDB_POSTGRES_PASSWORD=testp-db-test-password
        TESTPDB_POSTGRES_URL=postgres://testp-db-test-user:testp-db-test-password@testp-db:5432/testp-db-test
        TESTPDB_POSTGRES_USER=testp-db-test-user
      ENVFILE
    end

    it "Generates correct env file" do
      metaproject.add_postgresql_instance "testp-db"
      metaproject.add_mysql_instance "testm-db"
      metaproject.add_redis_instance "cache"
      metaproject.add_rack_project "somerack"
      metaproject.add_localgem_project "some_local_gem"

      result = Mobilis::OutputFiles::Env.new(:test, metaproject).render
      expect(result).to eq(expected)
    end
  end
end
