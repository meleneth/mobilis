# frozen_string_literal: true

RSpec.describe "Rack Project" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_rack_project "some_rack_project"
  end

  before do
    allow(project).to receive(:username).and_return("testuser")
  end

  describe "#linked_to_localgem_project" do
    it "works" do
      rack = project.add_rack_project "some_rack_project"
      project.add_localgem_project "some_nifty_gem"
      rack.set_links(["some_nifty_gem"])
      expect(rack.linked_to_localgem_project).to eq(true)
    end
  end

  describe "Dockerfile" do
    it "Generates basic Dockerfile" do
      project.add_rack_project "some_rack_project"
      expected = <<EXPECTED_DOCKERFILE
FROM ruby:latest
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp
# Add a script to be executed every time the container starts.
ENTRYPOINT ["rackup", "-o", "some_rack_project"]
EXPOSE 9292
EXPECTED_DOCKERFILE
      expect(project.projects[0].get_Dockerfile).to eq(expected)
    end
    it "Generates complicated Dockerfile for localgems" do
      rack = project.add_rack_project "some_rack_project"
      project.add_localgem_project "some_nifty_gem"
      rack.set_links(["some_nifty_gem"])

      expected = <<EXPECTED_DOCKERFILE
FROM ruby:latest as gem-cache
RUN mkdir -p /usr/local/bundle
RUN gem install bundler:2.4.12
FROM gem-cache AS gems
WORKDIR /myapp
COPY localgems/* /myapp
WORKDIR /myapp/some_nifty_gem
RUN bundle install
RUN rake install
FROM gem-cache as final
COPY --from=gems /usr/local/bundle /usr/local/bundle
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp
# Add a script to be executed every time the container starts.
ENTRYPOINT ["rackup", "-o", "some_rack_project"]
EXPOSE 9292
EXPECTED_DOCKERFILE
      expect(project.projects[0].get_Dockerfile).to eq(expected)
    end
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
