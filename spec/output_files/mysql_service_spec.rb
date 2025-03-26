# frozen_string_literal: true

RSpec.describe "MySQL Instance" do
  let(:project) { build(:metaproject) }

  it "is addable" do
    project.add_mysql_instance "test-db"
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "services" => {
          "test-db" => {
            "image" => "mysql:debian",
            "restart" => "always",
            "environment" => [
              "MYSQL_USER=${TEST_DB_MYSQL_USER}",
              "MYSQL_PASSWORD=${TEST_DB_MYSQL_PASSWORD}",
              "MYSQL_RANDOM_ROOT_PASSWORD=true"
            ],
            "ports" => ["${TEST_DB_EXTERNAL_PORT_NO}:${TEST_DB_INTERNAL_PORT_NO}"],
            "volumes" => [
              "${TEST_DB_MYSQL_DATA}:/var/lib/mysql"
            ]
          }
        }
      }
    end

    it "Generates correct service" do
      mysql_service = project.add_mysql_instance "test-db"
      result = YAML.safe_load(Mobilis::OutputFiles::MySQLService.new(mysql_service).render, aliases: true)
      expect(result).to eq(expected)
    end
  end
end
