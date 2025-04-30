# frozen_string_literal: true

require "git"
module Mobilis
  # here it is, the main class that actually orchestratest the entire
  # dance of file creation.
  class Manifest
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :system, :realized_envs, :directory_service, :git_repo

    def initialize(system, suppress_plugins: false)
      @system = system
      @directory_service = Mobilis::Services::Directory.new
      @realized_envs = environments.map do |env|
        Mobilis::RealizedEnv.new(system, env)
      end
      return if suppress_plugins

      setup_plugins
      run_plugin_hooks :hook_envs_realized
    end

    def realized_production_env
      @realized_envs.find(&:is_production?)
    end

    def realized_env(target_env)
      @realized_envs.each do |env|
        return env if env.to_s == target_env.to_s
      end
      raise "No such environment #{target_env} for manifest"
    end

    def materialize
      directory_service.chdir_start
      directory_service.mkdir_generate
      directory_service.mkdir_compose
      directory_service.chdir_generate
      write_gitignore
      @git_repo = Git.init(".")
      commit_all("Basic .gitignore")
      run_plugin_hooks :hook_before_services_written
      emit_all_services
      emit_compose_wrappers
      emit_env_files
      write_overrides_for(:development)
      write_overrides_for(:production)
      commit_all("Compose overrides")
    end

    def write_gitignore
      File.open(".gitignore", "w") do |f|
        f.write("data\n")
      end
    end

    def commit_all(message)
      puts " -- git commit: #{message} --"
      @git_repo.add(all: true)
      @git_repo.commit("[mobilis] #{message}")
    end

    def setup_plugins
      @plugins = realized_envs
                 .flat_map(&:required_plugins)
                 .uniq
                 .map { |klass| klass.new(self) }
    end

    def run_plugin_hooks(hook)
      @plugins.each do |plugin|
        plugin.send(hook)
      end
    end

    def plugin_for(klass)
      @plugins.each do |plugin|
        return plugin if plugin.instance_of? klass
      end
    end

    def each_node_of_type(klass, &block)
      return enum_for(:each_node_of_type) unless block_given?

      @realized_envs.each do |realized_env|
        realized_env.each_node_of_type(klass, &block)
      end
    end

    def ppx_fields(dsl)
      dsl.child_object "system", @system
      dsl.child_object "directory_service", @directory_service
      @realized_envs.each do |realized_env|
        dsl.child_object realized_env.environment, realized_env
      end
    end

    def username
      ENV.fetch("USER", ENV.fetch("USERNAME", ""))
    end

    def depends_on_overrides_for(target_env)
      test_env = realized_env(:test)
      return nil if test_env.equal?(target_env)

      overrides = { services: {} }

      target_env.each_node do |node|
        target_compose = node.compose[:services][node.name]
        target_deps = target_compose[:depends_on]
        next unless target_deps

        test_deps =
          begin
            test_node = test_env.realized_node_by_name(node.name)
            test_node.compose[:services][test_node.name][:depends_on]
          rescue Mobilis::NoSuchNode
            nil
          end

        next if target_deps == test_deps

        overrides[:services][node.name] = { depends_on: target_deps }
      end

      overrides[:services].empty? ? nil : overrides
    end

    private

    def environments
      %i[test development production].map do |env|
        Mobilis::ExecutionEnvironment.new env
      end
    end

    def emit_env_files
      directory_service.chdir_generate
      @realized_envs.each do |realized_env|
        lines = []
        realized_env.nodes.each do |node|
          node.per_env_vars do |env_var|
            lines << env_var.env_repr
          end
        end
        File.write("#{realized_env.environment}.env", "#{lines.join("\n")}\n")
      end
      commit_all "env files"
    end

    def emit_compose_wrappers
      directory_service.chdir_generate
      @realized_envs.each do |realized_env|
        details = {}
        details["name"] = "generate-#{realized_env}"
        includes = []
        realized_env.nodes.each do |node|
          node_details = {}
          node_details["path"] = "./compose/#{node.name}.yml"
          node_details["project_directory"] = "./"
          node_details["env_file"] = "./#{realized_env.environment}.env"
          includes << node_details
        end
        details["include"] = includes
        File.write("#{realized_env}-compose.yml", ::YAML.dump(details))
      end
      commit_all("compose wrappers")
    end

    def emit_all_services
      service_dirs_written = {}
      @realized_envs.each do |realized_env|
        realized_env.nodes.each do |node|
          name = node.name

          if node.has_service_dir
            next if service_dirs_written[name]

            directory_service.mkdir_project(node)
            directory_service.chdir_project(node)
            writer = node.service_writer.new(self, realized_env, node)
            writer.write
            directory_service.chdir_generate
            service_dirs_written[name] = true
          end
          directory_service.chdir_generate
          directory_service.mkdir_environment_datadir_forproject(realized_env.environment, node) if node.has_data_volume

          File.write("compose/#{node.name}.yml", ::YAML.dump(Mobilis::YAML.deep_stringify_keys(node.compose)))
        end
      end
    end

    def write_overrides_for(env)
      overrides = depends_on_overrides_for(realized_env(env))
      return if overrides.nil?

      File.write("#{env}-overrides.yml", ::YAML.dump(Mobilis::YAML.deep_stringify_keys(overrides)))
    end
  end
end
