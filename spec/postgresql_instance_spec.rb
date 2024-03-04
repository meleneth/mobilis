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
            "image" => "postgres:16.1-bookworm",
            "restart" => "always",
            "environment" => [
              "POSTGRES_USER=${TEST_DB_POSTGRES_USER}",
              "POSTGRES_PASSWORD=${TEST_DB_POSTGRES_PASSWORD}"
            ],
            "ports" => ["${TEST_DB_EXPOSED_PORT_NO}:${TEST_DB_INTERNAL_PORT_NO}"],
            "volumes" => [
              "${TEST_DB_POSTGRES_DATA}:/var/lib/postgresql/data"
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
        TEST_DB_INTERNAL_PORT_NO: 5432,
        TEST_DB_EXTERNAL_PORT_NO: 9999,
        TEST_DB_POSTGRES_DB: "test-db_test",
        TEST_DB_POSTGRES_USER: "test-db",
        TEST_DB_POSTGRES_PASSWORD: "test-db_password",
        TEST_DB_POSTGRES_DATA: "./data/test/test-db",
        TEST_DB_POSTGRES_URL: "postgres://test-db:test-db_password@test-db:5432/"
      })
    end
  end
end
