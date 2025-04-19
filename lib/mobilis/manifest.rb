# frozen_string_literal: true

module Mobilis
  # here it is, the main class that actually orchestratest the entire
  # dance of file creation.
  class Manifest
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :system, :realized_envs, :directory_service

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
      run_plugin_hooks :hook_before_services_written
      emit_all_services
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

    private

    def environments
      %i[test development production].map do |env|
        Mobilis::ExecutionEnvironment.new env
      end
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
            node.service_writer.new(self, realized_env, node).write
            directory_service.chdir_generate
            service_dirs_written[name] = true
          end

          if node.has_data_volume
            directory_service.mkdir_environment_datadir_forproject(realized_env.environment,
                                                                   node)
          end
        end
      end
    end
  end
end
