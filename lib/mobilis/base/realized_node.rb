# frozen_string_literal: true

require "forwardable"

# Abstract base class for environment-specific node representations.
# Created during RealizedEnv construction — never serialized.
module Mobilis
  module Base
    class RealizedNode
      include Mobilis::Mixins::RealizedNode::HasCommand
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

      def_delegators :@config_node, :name, :each_model_of_type, :internal_url_scheme
      def_delegators :@realized_env, :meta_project_name

      # @param env [Mobilis::RealizedEnv]
      # @param node [Mobilis::Node]
      def initialize(realized_env, config_node)
        @realized_env = realized_env
        @config_node = config_node
        @has_data_volume = false
        @has_service_dir = false
        @has_dockerfile = false
        @extra_depends_on = Marshal.load(Marshal.dump(config_node.extra_depends_on))
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

      def internal_url
        return nil unless respond_to?(:exposed_port_no)

        "#{internal_url_scheme}://#{name}:#{exposed_port_no}"
      end

      def dependency_url_envfile_name(provider)
        "#{name}__#{provider.name}_url"
      end

      def dependency_url_container_name(provider)
        "#{provider.name}_url"
      end

      def add_dependency_url(provider, container_name: nil)
        url = provider.internal_url
        return nil unless url
        envfile_name = dependency_url_envfile_name(provider)
        existing = compose_environment.data.find do |emit_var|
          emit_var.envfile_name == envfile_name.to_s.upcase.tr("-", "_")
        end
        return existing if existing

        add_compose_aliased_var(
          container_name || dependency_url_container_name(provider),
          envfile_name,
          url
        )
      end

      def connected_nodes(klass)
        extra_depends_on.filter_map do |edge|
          target = edge[:target]
          next unless target

          provider = target.is_a?(Mobilis::Base::RealizedNode) ? target : realized_env.realized_node_for_config_node(target)
          provider if provider.is_a?(klass)
        end.uniq
      end

      def populate_compose_depends_on
        brokers = connected_nodes(Mobilis::Realized::GooglePubSub)
        raise ArgumentError, "#{name} supports one Pub/Sub emulator connection" if brokers.length > 1

        extra_depends_on.each do |extra_dep|
          target = extra_dep[:target]
          provider =
            if target.is_a?(Mobilis::Base::RealizedNode)
              target
            elsif target.is_a?(Mobilis::Base::Node)
              realized_env.realized_node_for_config_node(target)
            end

          raise Mobilis::NoSuchNode.new("Could not find realized dependency for #{name}") unless provider

          register_depends_on(provider, force_skip_health_checks: extra_dep[:force_skip_health_checks] == true)
          add_dependency_url(provider)
          if provider.is_a?(Mobilis::Realized::Cassandra)
            provider.connection_values.each do |key, value|
              if %w[CASSANDRA_USERNAME CASSANDRA_PASSWORD].include?(key)
                suffix = key == "CASSANDRA_USERNAME" ? "user" : "password"
                add_compose_aliased_var(key, "#{provider.name}_cassandra_#{suffix}", value)
              else
                add_compose_raw_var(key, value)
              end
            end
          end
          if provider.is_a?(Mobilis::Realized::GooglePubSub)
            publishes = Array(extra_dep[:pubsub_publish])
            consumes = Array(extra_dep[:pubsub_subscribe])
            if publishes.empty? && consumes.empty?
              raise ArgumentError, "#{name} Pub/Sub connection requires publish or subscribe declarations"
            end
            add_compose_raw_var("PUBSUB_EMULATOR_HOST", "#{provider.name}:#{Mobilis::Realized::GooglePubSub::PORT}")
            add_compose_raw_var("PUBSUB_PROJECT_ID", provider.config_node.project_id)
            add_compose_raw_var("GOOGLE_CLOUD_PROJECT", provider.config_node.project_id)
            add_compose_raw_var("MOBILIS_PUBSUB_PUBLISH_TOPICS", publishes.join(","))
            add_compose_raw_var("MOBILIS_PUBSUB_SUBSCRIPTIONS", consumes.join(","))
          end
        end
      end
    end
  end
end
