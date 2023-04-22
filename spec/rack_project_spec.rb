# frozen_string_literal: true

RSpec.describe "Rack Project" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_rack_project "some_rack_project"
  end

  before do
    allow(project).to receive(:username).and_return("testuser")
  end

  describe "docker-compose" do
    let(:expected) do
      {
        "version" => "3.8",
        "services" => {
          "some_rack_project" => {
            "image" => "testuser/some_rack_project",
            "ports" => [
              "10000:9292"
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
      project.add_rack_project "some_rack_project"
      result = Mobilis::DockerComposeProjector.project project
      expect(result).to eq(expected)
    end
  end

end
