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
            "image" => "postgres:15.2-alpine",
            "restart" => "always",
            "environment" => [
              "POSTGRES_USER_TEST_DB=test-db",
              "POSTGRES_PASSWORD_TEST_DB=test-db_password"
            ],
            "ports" => ["10000:5432"],
            "volumes" => [
              "./data/test-db:/var/lib/postgresql/data"
            ],
          }
        }
      }
    end

    it "Generates correct service" do
      project.add_postgresql_instance "test-db"
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end
  end
end
