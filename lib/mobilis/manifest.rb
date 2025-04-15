# frozen_string_literal: true

module Mobilis
  # here it is, the main class that actually orchestratest the entire
  # dance of file creation.
  class Manifest
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :system, :realized_envs, :directory_service

    def initialize(system)
      @system = system
      @directory_service = Mobilis::Services::Directory.new
      @realized_envs = environments.map do |env|
        Mobilis::RealizedEnv.new(system, env)
      end
    end

    def materialize
      directory_service.chdir_start
      run_plugin_hooks :hook_before_services_written
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

    private

    def environments
      %i[test development production].map do |env|
        Mobilis::ExecutionEnvironment.new env
      end
    end
  end
end
