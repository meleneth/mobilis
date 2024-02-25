# frozen_string_literal: true

RSpec.describe "Acceptance" do
  let(:project) { Mobilis::Project.new }

  describe "simple prime account service with default postgres db" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "account" => {
            "image" => "testuser/account",
            "ports" => [
              "10000:3000"
            ],
            "environment" => [
              "RAILS_ENV=production",
              "RAILS_MASTER_KEY=",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
              "DATABASE_URL=postgres://account-db:account-db_password@account-db:5432/"
            ],
            "build" => {
              "context" => "./account"
            },
            "links" => [
              "account-db"
            ],
            "depends_on" => [
              "account-db"
            ]
          },
          "account-db" => {
            "image" => "postgres:16.1-bookworm",
            "restart" => "always",
            "environment" => [
              "POSTGRES_DB=${ACCOUNT_DB_POSTGRES_DB}",
              "POSTGRES_USER=${ACCOUNT_DB_POSTGRES_USER}",
              "POSTGRES_PASSWORD=${ACCOUNT_DB_POSTGRES_PASSWORD}"
            ],
            "ports" => [
              "10100:5432"
            ],
            "volumes" => [
              "${ACCOUNT_DB_POSTGRES_DATA}:/var/lib/postgresql/data"
            ]
          }
        }
      }
    end

    before do
      allow(project).to receive(:username).and_return("testuser")
    end
    it "Generates correct service" do
      prime_stack = project.add_prime_stack_rails_project "account"
      prime_stack.add_linked_postgresql_instance "account-db"
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "prime" => {
            "links" => ["testp-db", "testm-db", "cache"],
            "image" => "testuser/prime",
            "build" => {
              "context" => "./",
              "dockerfile" => "./prime/Dockerfile"
            },
            "depends_on" => ["testp-db", "testm-db", "cache"],
            "environment" => [
              "RAILS_ENV=production",
              "RAILS_MASTER_KEY=",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
              "DATABASE_URL=postgres://testp-db:testp-db_password@testp-db:5432/",
              "REDIS_HOST_CACHE=cache",
              "REDIS_PORT_CACHE=6379",
              "REDIS_PASSWORD_CACHE=cache_password"
              #              "NEW_RELIC_APP_NAME=prime",
              #              "NEW_RELIC_LICENSE_KEY=some_invalid_key_NREAL",
              #              "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true"
            ],
            "ports" => ["10000:3000"]
          },
          "testp-db" => {
            "image" => "postgres:16.1-bookworm",
            "restart" => "always",
            "environment" => [
              "POSTGRES_DB=${TESTP_DB_POSTGRES_DB}",
              "POSTGRES_USER=${TESTP_DB_POSTGRES_USER}",
              "POSTGRES_PASSWORD=${TESTP_DB_POSTGRES_PASSWORD}"
            ],
            "ports" => ["10100:5432"],
            "volumes" => [
              "${TESTP_DB_POSTGRES_DATA}:/var/lib/postgresql/data"
            ]
          },
          "testm-db" => {
            "image" => "mysql:debian",
            "restart" => "always",
            "environment" => [
              "MYSQL_DATABASE=${TESTM_DB_MYSQL_DATABASE}",
              "MYSQL_USER=${TESTM_DB_MYSQL_USER}",
              "MYSQL_PASSWORD=${TESTM_DB_MYSQL_PASSWORD}",
              "MYSQL_RANDOM_ROOT_PASSWORD=true"
            ],
            "ports" => ["10200:3306"],
            "volumes" => [
              "${TESTM_DB_MYSQL_DATA}:/var/lib/mysql"
            ]
          },
          "cache" => {
            "image" => "redis:7.2.3-alpine",
            "restart" => "always",
            "environment" => [],
            "ports" => ["10300:6379"],
            "command" => "redis-server --save 20 1 --loglevel warning --requirepass cache_password",
            "volumes" => [
              "./data/cache:/data"
            ]
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
      prime_stack.set_links(["testp-db", "testm-db", "cache", "some_local_gem"])
      project.new_relic do
        set_license_key "some_invalid_key_NREAL"
        enable_distributed_tracing
      end
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end
  end
end
