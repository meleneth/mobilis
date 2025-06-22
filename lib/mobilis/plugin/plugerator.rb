# frozen_string_literal: true

module Mobilis
  module Plugin
    # spawns a otel collector integration plugin for nodes we support, just rails at first
    class Plugerator < Mobilis::Base::Plugin
      def generate_per_node_plugins
        # OpenTelemetry Instrumentation
        should_install_otel_rails_integration = lambda do |realized_env, realized_node|
          return false unless realized_env.is_test?
          return false unless realized_node.config_node.has_connected_depends_on_class?(Mobilis::Node::OtelCollector)

          true
        end

        generate_plugins_for(Mobilis::Realized::Rails,
                             Mobilis::Plugin::OTELRailsIntegration,
                             should_install_otel_rails_integration)

        # Rails GraphQL installation
        should_install_rails_graphql_integration = lambda do |realized_env, realized_node|
          return false unless realized_env.is_test?
          return false unless realized_node.config_node.has_model_class?(Mobilis::Model::Rails::GraphQL)

          true
        end

        generate_plugins_for(Mobilis::Realized::Rails,
                             Mobilis::Plugin::GraphQLRailsIntegration,
                             should_install_rails_graphql_integration)
      end

      def generate_plugins_for(target_realized_node_class, target_plugin_class, node_matcher)
        @manifest.each_node_of_type(target_realized_node_class) do |realized_env, realized_node|
          next unless node_matcher.call(realized_env, realized_node)

          new_plugin = target_plugin_class.new(@manifest, realized_node)
          @manifest.add_plugin(new_plugin)
        end
      end
    end
  end
end
