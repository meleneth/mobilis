# frozen_string_literal: true

RSpec.describe "MySQL Instance" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_mysql_instance "test-db"
  end

  describe "docker-compose" do
    it "has global_env_vars" do
      project.add_mysql_instance "test-db"
      expect(project.projects[0].global_env_vars("test")).to eq({
                                                                  TEST_DB_EXTERNAL_PORT_NO: "AUTO_EXTERNAL_PORT",
                                                                  TEST_DB_INTERNAL_PORT_NO: 3306,
                                                                  TEST_DB_MYSQL_USER: "test-db",
                                                                  TEST_DB_MYSQL_PASSWORD: "test-db_password",
                                                                  TEST_DB_MYSQL_DATA: "./data/test/test-db",
                                                                  TEST_DB_MYSQL_URL: "mysql2://test-db:test-db_password@test-db:3306/?pool=5"
                                                                })
    end
  end
end
