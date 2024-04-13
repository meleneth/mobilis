# frozen_string_literal: true

RSpec.describe "Postgresql Instance" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_postgresql_instance "test-db"
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "test-db" => {
            "image" => "postgres:16.2-bookworm",
            "restart" => "always",
            "user" => "${RUNASUSER}",
            "environment" => [
              "POSTGRES_USER=${TESTDB_POSTGRES_USER}",
              "POSTGRES_PASSWORD=${TESTDB_POSTGRES_PASSWORD}"
            ],
            "ports" => ["${TESTDB_EXTERNAL_PORT_NO}:${TESTDB_INTERNAL_PORT_NO}"],
            "volumes" => [
              "${TESTDB_POSTGRES_DATA}:/var/lib/postgresql/data"
            ]
          }
        }
      }
    end

    it "Generates correct service" do
      project.add_postgresql_instance "test-db"
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end

    it "has global_env_vars" do
      project.add_postgresql_instance "test-db"
      expect(project.projects[0].global_env_vars("test")).to eq({
        TESTDB_INTERNAL_PORT_NO: 5432,
        TESTDB_EXTERNAL_PORT_NO: "AUTO_EXTERNAL_PORT",
        TESTDB_POSTGRES_DB: "test-db-test",
        TESTDB_POSTGRES_USER: "test-db-test-user",
        TESTDB_POSTGRES_PASSWORD: "test-db-test-password",
        TESTDB_POSTGRES_DATA: "./data/test/test-db",
        TESTDB_POSTGRES_URL: "postgres://test-db-test-user:test-db-test-password@test-db:5432/test-db-test"
      })
    end

    it "some items change based on env" do
      project.add_postgresql_instance "test-db"
      expect(project.projects[0].global_env_vars("development")).to eq({
        TESTDB_INTERNAL_PORT_NO: 5432,
        TESTDB_EXTERNAL_PORT_NO: "AUTO_EXTERNAL_PORT",
        TESTDB_POSTGRES_DB: "test-db-development",
        TESTDB_POSTGRES_USER: "test-db-development-user",
        TESTDB_POSTGRES_PASSWORD: "test-db-development-password",
        TESTDB_POSTGRES_DATA: "./data/development/test-db",
        TESTDB_POSTGRES_URL: "postgres://test-db-development-user:test-db-development-password@test-db:5432/test-db-development"
      })
    end
  end
end
