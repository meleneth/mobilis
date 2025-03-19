# frozen_string_literal: true

RSpec.describe "Rack Project" do
  let(:project) { Mobilis::Project.new }

  before do
    allow(project).to receive(:username).and_return("testuser")
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "services" => {
          "some_rack_project" => {
            "image" => "testuser/some_rack_project",
            "ports" => [
              "${SOME_RACK_PROJECT_EXTERNAL_PORT_NO}:${SOME_RACK_PROJECT_INTERNAL_PORT_NO}"
            ],
            "environment" => [],
            "build" => {
              "context" => "./some_rack_project"
            }
          }
        }
      }
    end

    it "Generates correct service" do
      rack_project = project.add_rack_project "some_rack_project"
      result = YAML.safe_load(Mobilis::OutputFiles::RackService.new(rack_project).render, aliases: true)
      expect(result).to eq(expected)
    end
  end
end
