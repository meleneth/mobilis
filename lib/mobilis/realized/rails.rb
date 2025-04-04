# frozen_string_literal: true

module Mobilis
  module Realized
    class Rails < Mobilis::Base::RealizedNode
      attr_reader :primary_database
      
      def initialize(env, node)
        super(env, node)

        @has_service_dir = true
        @has_data_volume = false

      end

      def after_all_nodes_realized(realized_env)
        return unless node.primary_database

        primary_database = realized_env.realized_node_for(node.primary_database)
      end
    end
  end
end
