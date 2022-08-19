# frozen_string_literal: true

RSpec.describe "Rails Project" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_rails_project "prime", [:rspec, :api, :simplecov, :standard, :factorybot]
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
            "image"=>"melen/prime",
            "environment"=> [
              "RAILS_ENV=production",
              "RAILS_MASTER_KEY=",
#              "NEW_RELIC_APP_NAME=prime",
#              "NEW_RELIC_LICENSE_KEY=some_invalid_key_NREAL",
#              "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true",
              "RAILS_MIN_THREADS=5",
              "RAILS_MAX_THREADS=5",
            ],
            "ports" => ["10000:3000"],
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
end
