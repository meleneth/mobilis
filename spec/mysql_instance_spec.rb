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
              "MYSQL_USER=test-db",
              "MYSQL_PASSWORD=test-db_password",
              "MYSQL_RANDOM_ROOT_PASSWORD=true"
            ],
            "ports" => ["10000:3306"],
            "volumes" => [
              "./data/test-db:/var/lib/mysql"
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
  end
end
