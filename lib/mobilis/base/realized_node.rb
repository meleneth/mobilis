# frozen_string_literal: true

require "forwardable"

# Abstract base class for environment-specific node representations.
# Created during RealizedEnv construction — never serialized.
module Mobilis
  module Base
    class RealizedNode
      include Mobilis::Mixins::RealizedNode::HasCompose
      include Mobilis::Mixins::RealizedNode::HasDependsOn
      include Mobilis::Mixins::RealizedNode::HasEnvVars
      include Mobilis::Mixins::RealizedNode::HasHealthCheck
      include Mobilis::Mixins::RealizedNode::HasOverrides
      include Mobilis::Mixins::RealizedNode::HasPorts
      include Mobilis::Mixins::RealizedNode::HasVolumes

      extend Forwardable

      attr_reader :config_node, :has_data_volume, :has_dockerfile, :has_service_dir, :realized_env
      attr_accessor :extra_depends_on

      def_delegators :@config_node, :name
      def_delegators :@realized_env, :meta_project_name

      # @param env [Mobilis::RealizedEnv]
      # @param node [Mobilis::Node]
      def initialize(realized_env, config_node)
        @realized_env = realized_env
        @config_node = config_node
        @has_data_volume = false
        @has_service_dir = false
        @has_dockerfile = false
        @extra_depends_on = config_node.extra_depends_on.dup
      end

      def environment
        realized_env.to_s
      end

      def after_all_nodes_realized
      end

      def required_plugins
        []
      end

      def service_writer
        raise "No service writer for #{self.class}"
      end

      def username
        ENV.fetch("USER", ENV.fetch("USERNAME", ""))
      end

      def dependant_services_require_restart?
        false
      end

      def populate_compose_depends_on
      end
    end
  end
end
