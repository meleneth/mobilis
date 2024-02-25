# frozen_string_literal: true

RSpec.describe "MySQL Instance" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_mysql_instance "test-db"
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "test-db" => {
            "image" => "mysql:debian",
            "restart" => "always",
            "environment" => [
              "MYSQL_USER=${TEST_DB_MYSQL_USER}",
              "MYSQL_PASSWORD=${TEST_DB_MYSQL_PASSWORD}",
              "MYSQL_RANDOM_ROOT_PASSWORD=true"
            ],
            "ports" => ["10000:3306"],
            "volumes" => [
              "${TEST_DB_MYSQL_DATA}:/var/lib/mysql"
            ]
          }
        }
      }
    end

    it "Generates correct service" do
      project.add_mysql_instance "test-db"
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end

    it "has global_env_vars" do
      project.add_mysql_instance "test-db"
      expect(project.projects[0].global_env_vars("test")).to eq({
        TEST_DB_MYSQL_USER: "test-db",
        TEST_DB_MYSQL_PASSWORD: "test-db_password",
        TEST_DB_MYSQL_DATA: "./data/test/test-db",
        TEST_DB_MYSQL_URL: "mysql2://test-db:test-db_password@test-db:3306/?pool=5"
      })
    end

  end
end
