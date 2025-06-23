# frozen_string_literal: true

require "fileutils"
require "git"

module Mobilis
  # here it is, the main class that actually orchestratest the entire
  # dance of file creation.
  class Manifest
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :system, :realized_envs, :directory_service, :git_repo, :plugins

    def initialize(system, suppress_plugins: false)
      @system = system
      @directory_service = Mobilis::Services::Directory.new
      @realized_envs = environments.map do |env|
        Mobilis::RealizedEnv.new(system, env)
      end

      return if suppress_plugins

      setup_plugins
      run_plugin_hooks :generate_per_node_plugins
      run_plugin_hooks :create_additional_services
    end

    def add_plugin(plugin)
      @plugins << plugin
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
      run_plugin_hooks :hook_after_services_written
      emit_compose_wrappers
      emit_env_files
      write_overrides_for(:test)
      write_overrides_for(:development)
      write_overrides_for(:production)
      commit_all("Compose overrides")
      write_commands_file
      commit_all("Commands file")
      write_mobilis_system
      commit_all("Mobilis system config")
      write_dc_helpers
      commit_all("docker compose helper scripts")
      Mobilis::Util.run_command(["./dc_test", "build"])
      run_plugin_hooks :hook_after_dc_helpers
      run_plugin_hooks :hook_create_rails_models
      run_plugin_hooks :hook_after_rails_models_created
      run_plugin_hooks :hook_run_commands
    end

    def write_mobilis_system
      directory_service.chdir_generate
      File.open("mobilis-system.json", "w") do |f|
        f.write(system.to_json)
      end
    end

    def write_commands_file
      directory_service.chdir_generate
      File.open("commands.txt", "w") do |f|
        f.write("Production:\n")
        f.write("HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose --env-file production.env -f production-compose.yml -f production-overrides.yml config\n")
        f.write("Development:\n")
        f.write("HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose --env-file development.env -f development-compose.yml -f development-overrides.yml config\n")
        f.write("Test:\n")
        f.write("HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose --env-file test.env -f test-compose.yml -f test-overrides.yml config\n")
      end
    end

    def write_dc_helpers
      write_dc_helper("dc_test", "test")
      write_dc_helper("dc_dev", "development")
      write_dc_helper("dc_prod", "production")
    end

    def write_dc_helper(filename, env_name)
      File.write(filename, <<~HERE)
        #!/usr/bin/env bash
        set -e

        ENV_FILE="#{env_name}.env"
        COMPOSE_FILE="compose/#{env_name}-compose.yml"

        ## Load .env only if it exists
        #[ -f "$ENV_FILE" ] && export $(grep -v '^#' "$ENV_FILE" | xargs)

        # Inject UID/GID for Unix-like systems
        if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
        	export HOST_UID=$(id -u)
        	export HOST_GID=$(id -g)
        fi

        exec docker compose --env-file #{env_name}.env -f #{env_name}-compose.yml -f #{env_name}-overrides.yml "$@"
      HERE
      FileUtils.chmod("+x", filename)
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
      @plugins << Mobilis::Plugin::WriteFiles.new(self)
      @plugins << Mobilis::Plugin::WriteScripts.new(self)
      @plugins << Mobilis::Plugin::Plugerator.new(self)
      @plugins << Mobilis::Plugin::RunCommands.new(self)
      @plugins
    end

    def run_plugin_hooks(hook)
      @plugins.dup.each do |plugin|
        plugin.send(hook)
      end
    end

    def run_node_hooks(hook)
      realized_envs.each do |realized_env|
        realized_env.dup.each_node do |realized_node|
          if block_given?
            realized_node.send(hook, &block)
          else
            realized_node.send(hook)
          end
        end
      end
    end

    def plugin_for(klass)
      @plugins.each do |plugin|
        return plugin if plugin.is_a? klass
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

    def overrides_for(realized_env)
      overrides = AutoVivify.new
      realized_env.realized_nodes.each do |node|
        overrides[:services][node.name].merge! node.compose_overrides
      end
      overrides.clean_shrunk
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
        vars_for_env = {}

        realized_env.all_envfile_vars do |emit_var|
          if vars_for_env.key? emit_var.key
            unless emit_var.value == vars_for_env[emit_var.envfile_name]
              raise "Different values for #{emit_var.envfile_name} - #{emit_var.value} vs #{vars_for_env[emit_var.envfile_name]}"
            end
          else
            vars_for_env[emit_var.envfile_name] = emit_var.value
          end
        end
        lines = vars_for_env.sort.map { |k, v| "#{k}=#{v}" }

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
        realized_env.realized_nodes.each do |node|
          node_details = {}
          node_details["path"] = "./compose/#{node.name}.yml"
          node_details["project_directory"] = "./"
          node_details["env_file"] = "./#{realized_env.environment}.env"
          includes << node_details
        end
        details["include"] = includes
        Mobilis::YAMLWriter.write_yaml("#{realized_env}-compose.yml", details)
      end
      commit_all("compose wrappers")
    end

    def emit_all_services
      service_dirs_written = {}
      @realized_envs.each do |realized_env|
        realized_env.realized_nodes.each do |realized_node|
          name = realized_node.name

          if realized_node.has_service_dir
            next if service_dirs_written[name]

            directory_service.mkdir_project(realized_node)
            directory_service.chdir_project(realized_node)
            writer = realized_node.service_writer.new(self, realized_env, realized_node)
            writer.write
            directory_service.chdir_generate
            service_dirs_written[name] = true
          end
          directory_service.chdir_generate
          if realized_node.has_data_volume
            directory_service.mkdir_environment_datadir_forproject(realized_env.environment,
                                                                   realized_node)
          end
          Mobilis::YAMLWriter.write_yaml("compose/#{realized_node.name}.yml",
                                         realized_node.service_wrapped_compose)
        end
      end
    end

    def write_overrides_for(raw_env)
      overrides = overrides_for(realized_env(raw_env))
      return if overrides.nil?

      Mobilis::YAMLWriter.write_yaml("#{raw_env}-overrides.yml", overrides)
    end
  end
end
