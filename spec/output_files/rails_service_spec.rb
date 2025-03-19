# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::OutputFiles::RailsService do
  let(:project) { Mobilis::Project.new }

  describe "simple prime account service with default postgres db" do
    let(:expected) do
      {
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
      result = YAML.safe_load(Mobilis::OutputFiles::RailsService.new(prime_stack).render, aliases: true)
      expect(result).to eq(expected)
    end
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "services" => {
          "prime" => {
            "links" => %w[testp-db testm-db cache],
            "image" => "testuser/prime",
            "build" => {
              "context" => "./",
              "dockerfile" => "./prime/Dockerfile"
            },
            "depends_on" => %w[testp-db testm-db cache],
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
      prime_stack.set_links(%w[testp-db testm-db cache some_local_gem])
      project.new_relic do
        set_license_key "some_invalid_key_NREAL"
        enable_distributed_tracing
      end
      result = YAML.safe_load(Mobilis::OutputFiles::RailsService.new(prime_stack).render, aliases: true)
      expect(result).to eq(expected)
    end
  end
end
