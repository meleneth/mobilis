# frozen_string_literal: true

require "fileutils"

module Mobilis
  ##
  # this is NOT a GenericProject, this is the metaproject
  # TODO: s/Project/Meta/g
  class Project
    include ActionsProjectsTake
    include Mobilis::NewRelic

    def initialize
      @data = {
        projects: [],
        username: ENV.fetch("USER", ENV.fetch("USERNAME", "")),
        starting_port_no: 10000,
        port_gap: 100,
        name: "generate"
      }
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
      if Dir.exist? target_directory
        puts "Removing existing #{target_directory} directory"
        FileUtils.rm_rf(target_directory)
      end

      Dir.mkdir target_directory

      Dir.chdir target_directory do
        save_project
        create_rails_builder if has_rails_project?
        projects.each_with_index do |project, index|
          project.generate
        end
        save_docker_compose
      end
    end

    def create_rails_builder
      Dir.mkdir "rails-builder"
      Dir.chdir "rails-builder" do
        create_rails_builder_dockerfile
        create_rails_builder_gemfile
        build_rails_builder
      end
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
        RUN addgroup --gid 200 rubyuser
        RUN adduser --disabled-password --gecos '' --uid 200 --gid 200 rubyuser
        USER rubyuser
      EOF
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
      attributes = {projects: {}, new_relic_license_key: ENV.fetch("NEW_RELIC_LICENSE_KEY", "some_invalid_key_NREAL")}
      projects.each_with_index do |project, index|
        attributes["#{project.name}_internal_port_no".to_sym] =
          @data[:starting_port_no] + (index * @data[:port_gap])
      end
      attributes
    end

    def build
      #  logger.info "# build"
      Dir.chdir "generate" do
        run_command "docker compose build"
      end
    end

    def rails_builder_image
      "#{username}/rails-builder"
    end

    def build_rails_builder
      run_docker "build -t #{rails_builder_image} --build-arg USER_ID=#{Process.uid} --build-arg GROUP_ID=#{Process.gid} ."
    end

    def load_from_file filename
      data = File.read filename
      @data = JSON.parse data, {symbolize_names: true}
    end

    def save_project
      File.write("mproj.json", JSON.pretty_generate(@data))
    end

    def save_docker_compose
      docker = DockerComposeProjector.project self

      File.write("docker-compose.yml", docker.to_yaml)
    end

    def projects
      mapping = {
        rails: RailsProject,
        postgresql: PostgresqlInstance,
        mysql: MysqlInstance,
        redis: RedisInstance,
        rack: RackProject,
        localgem: LocalgemProject
      }
      @data[:projects].map { |p| mapping[p[:type].to_sym].new p, self }
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
      @data[:projects] << data
      GenericProject.new data, self
    end

    def add_mysql_instance name
      data = {
        name: name,
        type: :mysql
      }
      @data[:projects] << data
      GenericProject.new data, self
    end

    def add_redis_instance name
      data = {
        name: name,
        type: :redis
      }
      @data[:projects] << data
      RedisInstance.new data, self
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
      @data[:projects] << data
      RailsProject.new data, self
    end

    def add_localgem_project name
      data = {
        name: name,
        type: :localgem,
        attributes: {}
      }
      @data[:projects] << data
      LocalgemProject.new data, self
    end

    def add_rack_project name
      data = {
        name: name,
        type: :rack,
        attributes: {}
      }
      @data[:projects] << data
      RackProject.new data, self
    end

    def getwd
      wd = Dir.getwd
      return wd unless wd[1] == ":"
      "/#{wd[0]}#{wd[2...]}"
    end
  end
end
