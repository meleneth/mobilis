# frozen_string_literal: true

RSpec.describe "Rails Project" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_rails_project "prime", [:rspec, :api, :simplecov, :standard, :factorybot]
  end

  before do
    allow(project).to receive(:username).and_return("testuser")
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "prime" => {
            "build" => {
              "context" => "./prime"
            },
            "image" => "testuser/prime",
            "environment" => [
              "RAILS_ENV=production",
              "RAILS_MASTER_KEY=",
              #              "NEW_RELIC_APP_NAME=prime",
              #              "NEW_RELIC_LICENSE_KEY=some_invalid_key_NREAL",
              #              "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5"
            ],
            "ports" => ["10000:3000"]
          }
        }
      }
    end

    it "Generates correct service" do
      project.add_rails_project "prime", [:rspec, :api, :simplecov, :standard, :factorybot]
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end
  end

  describe "models" do
    # rails g scaffold Author name:string
    # rails g scaffold Post title:string description:text author:references
    # rails g scaffold Comment title:string content:text score:integer author:references post:references
    # rails g scaffold FlaggedForReview comment:references status:string
  end

  describe "#wait_until_line" do
    it "Generates correct line for MySQL" do
      prime_stack = project.add_rails_project "prime", [:rspec, :api, :simplecov, :standard, :factorybot]
      project.add_mysql_instance "testm-db"
      prime_stack.set_links(["testm-db"])
      expect(prime_stack.wait_until_line).to eq <<~MYSQL_LINE
        /myapp/wait-until "mysql -D prime_production -h testm-db -u testm-db -ptestm-db_password -e 'select 1'"
      MYSQL_LINE
    end
    it "Generates correct line for Postgres" do
      prime_stack = project.add_rails_project "prime", [:rspec, :api, :simplecov, :standard, :factorybot]
      project.add_postgresql_instance "testp-db"
      prime_stack.set_links(["testp-db"])
      expect(prime_stack.wait_until_line).to eq <<~POSTGRES_LINE
        /myapp/wait-until "psql postgres://testp-db:testp-db_password@testp-db/prime_production -c 'select 1'"
      POSTGRES_LINE
    end
  end
end
