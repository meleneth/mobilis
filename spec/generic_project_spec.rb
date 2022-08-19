# frozen_string_literal: true

RSpec.describe "Generic Project" do
  let(:project) { Mobilis::Project.new }
  let(:prime_stack) { project.add_prime_stack_rails_project "prime" }
  let(:mysql_instance) { project.add_mysql_instance "testm-db" }

  describe "#children" do
    it "has linked projects" do
      prime_stack.set_links([mysql_instance.name])
      expect(prime_stack.children[0].name).to eq("testm-db")
    end
  end

  describe "#parents" do
    it "has projects that link to us" do
      prime_stack.set_links([mysql_instance.name])
      expect(mysql_instance.parents[0].name).to eq("prime")
    end
  end

  describe "#linked_to_rails_project" do
    it "returns first linked rails project, if there is one" do
      prime_stack.set_links([mysql_instance.name])
      expect(mysql_instance.linked_to_rails_project.name).to eq("prime")
    end
  end

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
