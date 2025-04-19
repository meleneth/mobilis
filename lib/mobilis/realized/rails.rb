# frozen_string_literal: true

module Mobilis
  module Realized
    class Rails < Mobilis::Base::RealizedNode
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :primary_database, :env_db_url

      def initialize(env, node)
        super(env, node)

        @has_service_dir = true
        @has_data_volume = false
      end

      def after_all_nodes_realized
        return unless node.primary_database

        @primary_database = @realized_env.node_for(node.primary_database)
        @env_db_url = @primary_database.env_db_url.as("DATABASE_URL")
        @env_vars << @env_db_url if @env_db_url
      end

      def required_plugins
        [Mobilis::Plugin::RailsBuilder, Mobilis::Plugin::RailsDBFanout]
      end

      def service_writer
        Mobilis::ServiceWriter::Rails
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "environment", environment
        dsl.instance_value "has_service_dir", has_service_dir
        dsl.instance_value "has_data_volume", has_data_volume
        dsl.child_object "env_db_url", env_db_url
        dsl.child_object "primary_database", primary_database
        dsl.child_object "node", node
        dsl.env_vars env_vars
      end
    end
  end
end
