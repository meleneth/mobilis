# frozen_string_literal: true

require "forwardable"

# Abstract base class for environment-specific node representations.
# Created during RealizedEnv construction — never serialized.
module Mobilis
  module Base
    class RealizedNode
      extend Forwardable

      attr_reader :env, :node, :port_maps, :env_vars
      attr_accessor :has_data_volume, :has_service_dir

      def_delegators :@node, :name

      # @param env [Mobilis::RealizedEnv]
      # @param node [Mobilis::Node]
      def initialize(env, node)
        @realized_env = env
        @node = node
        @port_maps = []
        @env_vars = []
        @per_env_vars = []
        @has_data_volume = false
        @has_service_dir = false
      end

      def environment
        @realized_env.to_s
      end

      def compose
        raise "class #{self.class} does not implement #compose"
      end

      def after_all_nodes_realized
      end

      def required_plugins
        []
      end

      def service_writer
        raise "No service writer for #{self.class}"
      end

      def env_var(resolved_name)
        @env_vars.each do |env_var|
          return env_var if env_var.specific_name == resolved_name
        end
        raise "No such environment variable #{specific_name} for #{name}"
      end

      def username
        ENV.fetch("USER", ENV.fetch("USERNAME", ""))
      end

      def env_var_resolved(resolved_name)
        @env_vars.each do |env_var|
          return env_var if env_var.resolved_name == resolved_name
        end
        raise "No such environment variable #{specific_name} for #{name}"
      end

      # rubocop:disable all
      def compose_env_vars
        return enum_for :compose_env_vars unless block_given?
        @env_vars.each do |env_var|
          yield env_var
        end
      end

      def per_env_vars
        return enum_for :per_env_vars unless block_given?
        @env_vars.each do |env_var|
          yield env_var
        end
        @per_env_vars.each do |env_var|
          yield env_var
        end
      end
      # rubocop:enable all

      def each_docker_env_var
        enum_for :each_docker_env_var unless block_given?
        env_vars.each do |env_var|
          yield env_var if env_var.instance_of? Mobilis::DockerEnvVar
        end
      end

      def has_healthcheck?
        healthcheck = compose[:services][name][:healthcheck]
        healthcheck.is_a?(Hash) && healthcheck.key?(:test)
      end

      def dependant_services_require_restart?
        false
      end
    end
  end
end
