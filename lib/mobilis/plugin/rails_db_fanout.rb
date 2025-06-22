# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsDBFanout < Mobilis::Base::Plugin
      extend Forwardable

      def generate_per_node_plugins
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_node.primary_database
          next unless realized_env.is_production?

          new_plugin = Mobilis::Plugin::RailsDBFanoutRealizedNode.new(@manifest, realized_node)
          @manifest.add_plugin(new_plugin)
        end
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
