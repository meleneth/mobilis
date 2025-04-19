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
        @has_data_volume = false
        @has_service_dir = false
      end

      def environment
        @realized_env.to_s
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
          return env_var if env_var.resolved_name == resolved_name
        end
        raise "No such environment variable #{resolved_name} for #{name}"
      end
    end
  end
end
