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
      def_delegators :@env, :environment

      # @param env [Mobilis::RealizedEnv]
      # @param node [Mobilis::Node]
      def initialize(env, node)
        @env = env
        @node = node
        @port_maps = []
        @env_vars = []
        @has_data_volume = false
        @has_service_dir = false
      end
    end
  end
end
