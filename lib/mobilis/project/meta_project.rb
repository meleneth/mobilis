# frozen_string_literal: true

require "fileutils"
require "git"

module Mobilis
  ##
  # this is NOT a GenericProject, this is the metaproject
  module Project
    class MetaProject
      include ActionsProjectsTake

      attr_accessor :data, :projects

      def initialize
        # @type var data: MetaProjectDataHash
        @data = {
          projects: [], # : Array[String]
          username: ENV.fetch("USER", ENV.fetch("USERNAME", "")),
          starting_port_no: 10_000,
          port_gap: 100,
          name: "generate"
        }
        @auto_port_index = 0
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
        ap to_h
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

      def each_target_environment
        return enum_for(:each_target_environment) unless block_given?

        %i[production development test].each { |env| yield Mobilis::ExecutionEnvironment.new(env) }
      end

      def each_datastore_project
        return enum_for(:each_datastore_project) unless block_given?

        projects.each do |p|
          yield p if p.is_datastore_project?
        end
      end

      def each_non_datastore_project
        return enum_for(:each_non_datastore_project) unless block_given?

        projects.each do |p|
          yield p unless p.is_datastore_project?
        end
      end

      def generate_files
        @directory_service.mkdir_generate
        @directory_service.chdir_generate
        save_project
        Git.init
        @directory_service.chdir_generate
        File.write(".gitignore", "data")
        @directory_service.git_commit_all("Project export")
        @directory_service.mkdir_compose
        generate_env_files
        save_docker_compose
        create_datastore_directories
        pull_dev_datastore_instances
        start_dev_datastore_instances
        create_project_instances
        @directory_service.chdir_generate
      end

      def has_datastore_instance?
        projects.any?(&:is_datastore_project?)
      end

      def runasuser
        "#{Process.uid}:#{Process.gid}"
      end

      def generate_env_files
        each_target_environment do |environment|
          Mobilis::OutputFiles::Env.new(environment, self).write_to("compose")
        end
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
        attributes = { projects: {} } # : Hash[(String | Symbol), untyped]
        projects.each_with_index do |project, index|
          attributes["#{project.name}_internal_port_no".to_sym] =
            @data[:starting_port_no] + (index * @data[:port_gap])
        end
        attributes
      end

      def build
        #  logger.info "# build"
        return_to_target_directory
        run_docker "compose -f compose-development.yml build"
      end

      def rails_builder_image
        "#{username}/rails-builder"
      end

      def build_rails_builder
        run_docker "build -t #{rails_builder_image} --build-arg USER_ID=#{Process.uid} --build-arg GROUP_ID=#{Process.gid} ."
      end

      def load_from_file(filename)
        data = File.read filename
        @data = JSON.parse data, { symbolize_names: true }
        raise "This is broken"
        # @projects = @data[:projects].map { |p| project_for_line(p) }
        projects = [] # : Array[untyped]
        @data[:projects] = projects
      end

      def save_project
        File.write("mproj.json", JSON.pretty_generate(to_h))
      end

      # rubocop:disable Style/ExplicitBlockArgument
      # it's normally a fine autofix, but it makes this function impossible for RBS sig
      def each_project_for_environment(target_environment = nil)
        return enum_for(:each_project_for_environment, target_environment) unless block_given?

        projects.each do |project|
          project.each_project_for_environment(target_environment) { |p| yield p }
        end
      end
      # rubocop:enable Style/ExplicitBlockArgument

      def save_docker_compose
        each_target_environment do |target_environment|
          Mobilis::OutputFiles::ComposeBase.new(target_environment, self).write_to(".")
          each_project_for_environment(target_environment) do |project|
            project.service_writer&.write_to("compose")
          end
        end
      end

      def project_by_name(name)
        projects.each do |project|
          return project if project.name == name
        end
        raise "Could not find project #{name}"
      end

      def display
        ap @data
      end

      def add_prime_stack_rails_project(name)
        add_rails_project name, %i[rspec api simplecov standard factorybot]
      end

      def add_omakase_stack_rails_project(name)
        add_rails_project name, %i[simplecov standard api]
      end

      def add_postgresql_instance(name)
        data = {
          name: name,
          type: :postgresql
        } # : Hash[name: String, type: Symbol, attributes: untyped]
        new_project = PostgreSQLInstance.new(data, self)
        @projects << new_project
        new_project
      end

      def add_mysql_instance(name)
        data = {
          name: name,
          type: :mysql
        } # : Hash[name: String, type: Symbol, attributes: untyped]
        new_project = MySQLInstance.new(data, self)
        @projects <<  new_project
        new_project
      end

      def add_redis_instance(name)
        data = {
          name: name,
          type: :redis
        } # : Hash[name: String, type: Symbol, attributes: untyped]
        new_project = RedisInstance.new(data, self)
        @projects << new_project
        new_project
      end

      def add_rails_project(name, options)
        data = {
          name: name,
          type: :rails,
          controllers: [], # : Array[untyped]
          models: [], # : Array[untyped]
          options: options.clone,
          attributes: {} # : Hash[String, untyped]
        } # : Hash[name: String, type: Symbol, attributes: untyped]
        new_project = RailsProject.new(data, self)
        @projects <<  new_project
        new_project
      end

      def add_kafka_instance(name)
        data = {
          name: name,
          type: :kafka,
          attributes: {} # : Hash[String, untyped]
        } # : Hash[name: String, type: Symbol, attributes: untyped]
        new_project = KafkaInstance.new(data, self)
        @projects << new_project
        new_project
      end

      def add_localgem_project(name)
        data = {
          name: name,
          type: :localgem,
          attributes: {} # : Hash[String, untyped]
        } # : Hash[name: String, type: Symbol, attributes: untyped]
        new_project = LocalgemProject.new(data, self)
        @projects << new_project
        new_project
      end

      def add_rack_project(name)
        data = {
          name: name,
          type: :rack,
          attributes: {} # : Hash[Symbol, untyped]
        } # : Hash[name: String, type: Symbol, attributes: untyped]
        new_project = RackProject.new(data, self)
        @projects << new_project
        new_project
      end

      def getwd
        wd = Dir.getwd
        return wd unless wd[1] == ":"

        "/#{wd[0]}#{wd[2...]}"
      end

      def to_h
        my_data = @data.clone
        my_data[:projects] = projects.collect(&:to_h)
        my_data
      end

      private

      def create_datastore_directories
        # creates storage directories, per-environment, per-datastore
        return unless has_datastore_instance?

        each_target_environment do |target_environment|
          @directory_service.mkdir_environment(target_environment)
          @directory_service.chdir_environment(target_environment)
          # TODO: make script for creating datastore directories after checkout, since
          # the db's will complain if they see a .gitkeep file
          # ... or maybe make the containers rm the mounted .gitkeep file?
          # anyways, we want it to work so here we go
          each_datastore_project do |project|
            @directory_service.mkdir_environment_datadir_forproject(target_environment, project)
            project.generate directory_service: @directory_service
          end
        end
        @directory_service.chdir_generate
        @directory_service.git_commit_all("environment datastore projects")
      end

      def pull_dev_datastore_instances
        @directory_service.chdir_generate
        each_datastore_project do |project|
          run_docker "compose -f compose-development.yml pull #{project.name}"
        end
      end

      def start_dev_datastore_instances
        @directory_service.chdir_generate
        each_datastore_project do |project|
          puts "Starting datastore project #{project.name}"
          run_docker "compose -f compose-development.yml up -d #{project.name}"
        end
        puts "Sleeping for one minute to give the DB's time to initialize..."
        sleep 60
      end

      def create_project_instances
        create_rails_builder if has_rails_project?
        each_non_datastore_project do |project|
          project.generate directory_service: @directory_service
        end
      end

      def next_auto_port_no
        @auto_port_index += 1
        @data[:starting_port_no] + (@data[:port_gap] * @auto_port_index)
      end
    end
  end
end
