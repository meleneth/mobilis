# frozen_string_literal: true

require "fileutils"
require 'git'

module Mobilis
  ##
  # this is NOT a GenericProject, this is the metaproject
  # TODO: s/Project/Meta/g
  class Project
    include ActionsProjectsTake
    include Mobilis::NewRelic

    attr_accessor :data
    attr_accessor :projects

    def initialize()
      @data = {
        projects: [],
        username: ENV.fetch("USER", ENV.fetch("USERNAME", "")),
        starting_port_no: 10000,
        port_gap: 100,
        name: "generate"
      }
      @projects = []
      @directory_service = Mobilis::Services::Directory.new
    end

    def return_to_start_directory
      @directory_service.chdir_start
    end

    def return_to_target_directory
      @directory_service.chdir_generate
    end

    def show
      ap @data
    end

    def name
      @data[:name]
    end

    def name=(name)
      @data[:name] = name
    end

    def attributes
      generate_attributes
    end

    def username
      @data[:username]
    end

    def target_directory
      "generate"
    end

    def generate_files
      @directory_service.mkdir_generate
      @directory_service.chdir_generate
      save_project
      Git.init
      create_rails_builder if has_rails_project?
      projects.each_with_index do |project, index|
        project.generate directory_service: @directory_service
      end
      @directory_service.chdir_generate
      save_docker_compose
      generate_gitignore
      generate_env_file
      @directory_service.git_commit_all("Docker compose file")
    end

    def generate_gitignore
      set_file_contents ".gitignore", <<~EOF
        .env
      EOF
    end

    def generate_env_file
      set_file_contents ".env", <<~EOF
        NEW_RELIC_LICENSE_KEY=
      EOF
    end

    def create_rails_builder
      @directory_service.mkdir_rails_builder
      @directory_service.chdir_rails_builder
      create_rails_builder_dockerfile
      create_rails_builder_gemfile
      build_rails_builder
    end

    def create_rails_builder_dockerfile
      set_file_contents "Dockerfile", <<~EOF
        FROM ruby:latest
        RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
        # Common dependencies
        RUN apt-get update -qq \\
          && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \\
            build-essential \\
            gnupg2 \\
            curl \\
            less \\
            git \\
            nodejs \\
            postgresql-client \\
          && apt-get clean \\
          && rm -rf /var/cache/apt/archives/* \\
          && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \\
          && truncate -s 0 /var/log/*log
        RUN gem update bundle
        RUN gem update --system

        COPY Gemfile .
        RUN bundle install

        ARG USER_ID
        ARG GROUP_ID
        RUN addgroup --gid $GROUP_ID rubyuser
        RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID rubyuser
        USER rubyuser
      EOF
      # it makes no sense that these values were hardcoded at 200 when I was passing
      # in the id's, why did that happen?
      # I assume it's because at some point something didn't work
      # so here's me taking notes trying to figure it out
      # using the args seems to have helped things a bit, but it didn't just work
      # Dir.chdir is conflicting with itself all over the place, time to stop using the block
      # form and get more in-control over where the CWD is
    end

    def create_rails_builder_gemfile
      set_file_contents "Gemfile", <<~EOF
        source "https://rubygems.org"
        # FIXME
        #git_source(:github) { |repo| "https://github.com/repo.git" }

        gem "rails"
        gem "sqlite3"
        gem "puma"
        gem "jbuilder"
        gem "redis"
        gem "kredis"
        gem "bcrypt"
        gem "bootsnap", require: false
        gem "image_processing"
        gem "rack-cors"
        gem "pg"
        gem "mysql2"
        gem "minitest"

        group :development, :test do
          gem "debug", platforms: %i[ mri mingw x64_mingw ]
        end

        group :development do
          gem "spring"
        end

        gem "rspec-rails", group: [:development, :test]
      EOF
    end

    def has_rails_project?
      projects.each do |p|
        return true if p.type.to_sym == :rails
      end
      false
    end

    def generate_attributes
      attributes = { projects: {}, new_relic_license_key: ENV.fetch("NEW_RELIC_LICENSE_KEY", "some_invalid_key_NREAL") }
      projects.each_with_index do |project, index|
        attributes["#{project.name}_internal_port_no".to_sym] =
          @data[:starting_port_no] + (index * @data[:port_gap])
      end
      attributes
    end

    def build
      #  logger.info "# build"
      return_to_target_directory
      run_command "docker compose build"
    end

    def rails_builder_image
      "#{username}/rails-builder"
    end

    def build_rails_builder
      run_docker "build -t #{rails_builder_image} --build-arg USER_ID=#{Process.uid} --build-arg GROUP_ID=#{Process.gid} ."
    end

    def load_from_file filename
      data = File.read filename
      @data = JSON.parse data, { symbolize_names: true }
      @projects = @data[:projects].map {|p| project_for_line(p) }
      @data[:projects] = []
    end

    def save_project
      File.write("mproj.json", JSON.pretty_generate(to_json))
    end

    def save_docker_compose
      docker = DockerComposeProjector.project self

      File.write("docker-compose.yml", docker.to_yaml)
    end

    def project_for_data data
      mapping = {
        kafka: KafkaInstance,
        localgem: LocalgemProject,
        mysql: MysqlInstance,
        postgresql: PostgresqlInstance,
        rack: RackProject,
        rails: RailsProject,
        redis: RedisInstance
      }
      mapping[data[:type].to_sym].new(data, self)
    end

    def project_by_name name
      projects.find { |p| p.name == name }
    end

    def display
      ap @data
    end

    def add_prime_stack_rails_project name
      add_rails_project name, [:rspec, :api, :simplecov, :standard, :factorybot]
    end

    def add_omakase_stack_rails_project name
      add_rails_project name, [:simplecov, :standard, :api]
    end

    def add_postgresql_instance name
      data = {
        name: name,
        type: :postgresql
      }
      @projects << PostgresqlInstance.new(data, self)
      @projects[-1]
    end

    def add_mysql_instance name
      data = {
        name: name,
        type: :mysql
      }
      @projects << MysqlInstance.new(data, self)
      @projects[-1]
    end

    def add_redis_instance name
      data = {
        name: name,
        type: :redis
      }
      @projects << RedisInstance.new(data, self)
      @projects[-1]
    end

    def add_rails_project name, options
      data = {
        name: name,
        type: :rails,
        controllers: [],
        models: [],
        options: options.clone,
        attributes: {}
      }
      @projects << RailsProject.new(data, self)
      @projects[-1]
    end

    def add_kafka_instance name
      data = {
        name: name,
        type: :kafka,
        attributes: {}
      }
      @projects << KafkaInstance.new(data, self)
      @projects[-1]
    end

    def add_localgem_project name
      data = {
        name: name,
        type: :localgem,
        attributes: {}
      }
      @projects << LocalgemProject.new(data, self)
      @projects[-1]
    end

    def add_rack_project name
      data = {
        name: name,
        type: :rack,
        attributes: {}
      }
      @projects << RackProject.new(data, self)
      @projects[-1]
    end

    def getwd
      wd = Dir.getwd
      return wd unless wd[1] == ":"

      "/#{wd[0]}#{wd[2...]}"
    end

    def to_json
      my_data = @data.clone
      my_data[:projects] = projects.collect(&:to_json)
      my_data
    end
  end
end
