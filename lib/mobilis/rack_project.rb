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
  set_file_contents "Dockerfile", get_Dockerfile
end

def get_Dockerfile
  localgem_lines = "FROM ruby:latest\n"
  localgem_lines = <<LOCALGEM_END if linked_to_localgem_project
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
LOCALGEM_END

  docker_lines = <<DOCKER_END
#{localgem_lines}RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp
# Add a script to be executed every time the container starts.
ENTRYPOINT ["rackup", "-o", "#{ name }"]
EXPOSE 9292
DOCKER_END
 docker_lines
end

end
end
