# frozen_string_literal: true

module Mobilis
  module Plugin
    # spawns a otel collector integration plugin for nodes we support, just rails at first
    class OTELPlugerator < Mobilis::Base::Plugin
      def generate_per_node_plugins
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_env.is_test?
          next unless realized_node.config_node.has_connected_depends_on_class?(Mobilis::Node::OtelCollector)

          new_plugin = Mobilis::Plugin::OTELRailsIntegration.new(@manifest, realized_node)
          yield new_plugin if block_given?
        end
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
