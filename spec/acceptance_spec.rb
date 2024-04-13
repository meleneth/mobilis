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
              "${ACCOUNT_EXTERNAL_PORT_NO}:${ACCOUNT_INTERNAL_PORT_NO}"
            ],
            "environment" => [
              "RAILS_ENV=production",
              "RAILS_MASTER_KEY=",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
              "DATABASE_URL=${ACCOUNT_DATABASE_URL}"
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
            "image" => "postgres:16.2-bookworm",
            "restart" => "always",
            "user" =>  "${RUNASUSER}",
            "environment" => [
              "POSTGRES_DB=${ACCOUNTDB_POSTGRES_DB}",
              "POSTGRES_USER=${ACCOUNTDB_POSTGRES_USER}",
              "POSTGRES_PASSWORD=${ACCOUNTDB_POSTGRES_PASSWORD}"
            ],
            "ports" => [
              "${ACCOUNTDB_EXTERNAL_PORT_NO}:${ACCOUNTDB_INTERNAL_PORT_NO}"
            ],
            "volumes" => [
              "${ACCOUNTDB_POSTGRES_DATA}:/var/lib/postgresql/data"
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
              "DATABASE_URL=${PRIME_DATABASE_URL}",
              "REDIS_HOST_CACHE=cache",
              "REDIS_PORT_CACHE=6379",
              "REDIS_PASSWORD_CACHE=cache_password"
              #              "NEW_RELIC_APP_NAME=prime",
              #              "NEW_RELIC_LICENSE_KEY=some_invalid_key_NREAL",
              #              "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true"
            ],
            "ports" => ["${PRIME_EXTERNAL_PORT_NO}:${PRIME_INTERNAL_PORT_NO}"]
          },
          "testp-db" => {
            "image" => "postgres:16.2-bookworm",
            "restart" => "always",
            "user" => "${RUNASUSER}",
            "environment" => [
              "POSTGRES_DB=${TESTPDB_POSTGRES_DB}",
              "POSTGRES_USER=${TESTPDB_POSTGRES_USER}",
              "POSTGRES_PASSWORD=${TESTPDB_POSTGRES_PASSWORD}"
            ],
            "ports" => ["${TESTPDB_EXTERNAL_PORT_NO}:${TESTPDB_INTERNAL_PORT_NO}"],
            "volumes" => [
              "${TESTPDB_POSTGRES_DATA}:/var/lib/postgresql/data"
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
            "ports" => ["${TESTM_DB_EXTERNAL_PORT_NO}:${TESTM_DB_INTERNAL_PORT_NO}"],
            "volumes" => [
              "${TESTM_DB_MYSQL_DATA}:/var/lib/mysql"
            ]
          },
          "cache" => {
            "image" => "redis:7.2.4-alpine",
            "restart" => "always",
            "environment" => [],
            "ports" => ["${CACHE_EXTERNAL_PORT_NO}:${CACHE_INTERNAL_PORT_NO}"],
            "command" => "redis-server --save 20 1 --loglevel warning --requirepass cache_password",
            "volumes" => [
              "./data/cache:/data"
            ]
          },
          "somerack" => {
            "image" => "testuser/somerack",
            "ports" => [
              "${SOMERACK_EXTERNAL_PORT_NO}:${SOMERACK_INTERNAL_PORT_NO}"
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
