# frozen_string_literal: true

RSpec.describe "Redis Instance" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_redis_instance "cache"
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "cache" => {
            "image" => "redis:7.2.4-alpine",
            "restart" => "always",
            "command" => "redis-server --save 20 1 --loglevel warning --requirepass cache_password",
            "environment" => [],
            "ports" => ["${CACHE_EXTERNAL_PORT_NO}:${CACHE_INTERNAL_PORT_NO}"],
            "volumes" => [
              "./data/cache:/data"
            ]
          }
        }
      }
    end

    it "Generates correct service" do
      project.add_redis_instance "cache"
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end
  end
end
