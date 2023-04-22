# frozen_string_literal: true

RSpec.describe "Acceptance" do
  let(:project) { Mobilis::Project.new }

  describe "docker-compose" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "prime" => {
            "links" => [ "testp-db", "testm-db", "cache" ],
            "image" => "testuser/prime",
            "build" => {
              "context" => "./prime",
            },
            "depends_on" => [ "testp-db", "testm-db", "cache" ],
            "environment" => [
              "RAILS_ENV=production",
              "RAILS_MASTER_KEY=",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
              "DATABASE_URL=postgres://testp-db:testp-db_password@testp-db:5432/",
              "REDIS_HOST=cache",
              "REDIS_PORT=6379",
              "REDIS_PASSWORD=cache_password",
#              "NEW_RELIC_APP_NAME=prime",
#              "NEW_RELIC_LICENSE_KEY=some_invalid_key_NREAL",
#              "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true"
            ],
            "ports" => ["10000:3000"],
          },
          "testp-db" => {
            "image" => "postgres:14.1-alpine",
            "restart" => "always",
            "environment" => [
              "POSTGRES_DB=prime_production",
              "POSTGRES_USER=testp-db",
              "POSTGRES_PASSWORD=testp-db_password"
            ],
            "ports" => ["10100:5432"],
            "volumes" => [
              "./data/testp-db:/var/lib/postgresql/data"
            ],
          },
          "testm-db" => {
            "image" => "mysql:debian",
            "restart" => "always",
            "environment" => [
              "MYSQL_DATABASE=prime_production",
              "MYSQL_USER=testm-db",
              "MYSQL_PASSWORD=testm-db_password",
              "MYSQL_RANDOM_ROOT_PASSWORD=true"
            ],
            "ports" => ["10200:3306"],
            "volumes" => [
              "./data/testm-db:/var/lib/mysql"
            ],
          },
          "cache" => {
            "image" => "redis:7.0.11-alpine",
            "restart" => "always",
            "environment" => [
            ],
            "ports" => ["10300:6379"],
            "command" => "redis-server --save 20 1 --loglevel warning --requirepass cache_password",
            "volumes" => [
              "./data/cache:/data"
            ],
          },
          "somerack" => {
            "image" => "testuser/somerack",
            "ports" => [
              "10400:9292"
            ],
            "environment" => [],
            "build" => {
              "context" => "./somerack"
            }
          }

        }
      }
    end
    before do
      allow(project).to receive(:username).and_return("testuser")
    end
    it "Generates correct service" do
      prime_stack = project.add_prime_stack_rails_project "prime"
      project.add_postgresql_instance "testp-db"
      project.add_mysql_instance "testm-db"
      project.add_redis_instance "cache"
      project.add_rack_project "somerack"
      project.add_localgem_project "some_local_gem"
      prime_stack.set_links(["testp-db", "testm-db", "cache"])
      project.new_relic do
        set_license_key "some_invalid_key_NREAL"
        enable_distributed_tracing
      end
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end
  end
end
