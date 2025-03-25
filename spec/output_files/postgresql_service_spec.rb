# frozen_string_literal: true

RSpec.describe "Postgresql Instance" do
  let(:project) { build(:metaproject) }

  describe "docker-compose" do
    let(:expected) do
      {
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
      postgresql_service = project.add_postgresql_instance "test-db"
      result = YAML.safe_load(Mobilis::OutputFiles::PostgreSQLService.new(postgresql_service).render, aliases: true)
      expect(result).to eq(expected)
    end
  end
end
