# frozen_string_literal: true

require "mobilis/generic_project"
require "mobilis/os"

module Mobilis
class RackProject < GenericProject

def name
  @data[:name]
end

def generate
  Dir.mkdir name
  Dir.chdir name do
    generate_config_ru
    generate_Gemfile
    generate_Gemfile_lock
    generate_Dockerfile
  end
end

def generate_config_ru
  set_file_contents "config.ru", <<CONFIG_RU
# config.ru
app = Proc.new {
  [
    200,
    { "content-type" => "text/html" },
    ["Hello, Rack"]
  ]
}
run app
CONFIG_RU
end

def generate_Gemfile
  set_file_contents "Gemfile", <<GEMFILE
# frozen_string_literal: true

source "https://rubygems.org"

# gem "rails"

gem "rack", "= 3.0.2"

gem "rackup", "~> 0.2.2"
GEMFILE
end

def generate_Gemfile_lock
  set_file_contents "Gemfile.lock", <<GEMFILE_LOCK
GEM
  remote: https://rubygems.org/
  specs:
    rack (3.0.2)
    rackup (0.2.2)
      rack (>= 3.0.2)
      webrick
    webrick (1.7.0)

PLATFORMS
  x64-mingw-ucrt

DEPENDENCIES
  rack (= 3.0.2)
  rackup (~> 0.2.2)

BUNDLED WITH
   2.3.16
GEMFILE_LOCK
end

def generate_Dockerfile
  set_file_contents "Dockerfile", <<DOCKER_END
FROM ruby:latest
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp

# Add a script to be executed every time the container starts.
ENTRYPOINT ["rackup", "-o", "#{ name }"]
EXPOSE 9292
DOCKER_END
end

end
end
