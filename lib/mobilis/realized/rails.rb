# frozen_string_literal: true

module Mobilis
  module Realized
    class Rails < Mobilis::Base::BuildForm
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :primary_database, :env_db_url

      def initialize(env, config_node)
        super(env, config_node)

        @has_service_dir = true
        @has_data_volume = false
      end

      def after_all_nodes_realized
        return unless config_node.primary_database

        @primary_database = @realized_env.realized_node_for_config_node(config_node.primary_database)
        @env_db_url = @primary_database.env_db_url.as("DATABASE_URL")
        add_env_var @env_db_url if @env_db_url
        add_basic_env_var("RAILS_ENV", environment.to_s)
        add_basic_env_var("RAILS_MIN_THREADS", 5)
        add_basic_env_var("RAILS_MAX_THREADS", 5)
      end

      def required_plugins
        [Mobilis::Plugin::RailsBuilder, Mobilis::Plugin::RailsDBFanout]
      end

      def service_writer
        Mobilis::ServiceWriter::Rails
      end

      def populate_compose_depends_on
        if primary_database
          compose_depends_on[ primary_database.name ] = {
            condition: primary_database.has_healthcheck? ? "service_healthy" : "service_started",
            restart: primary_database.dependant_services_require_restart?
          }.compact

        end
        extra_depends_on.each do |other_node|
          compose_depends_on[other_node.name] = {
            condition: other_node.has_healthcheck? ? "service_healthy" : "service_started",
            restart: other_node.dependant_services_require_restart?
          }.compact
        end
      end

      def service_dir_mounts
        nil
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "environment", environment
        dsl.instance_value "has_service_dir", has_service_dir
        dsl.instance_value "has_data_volume", has_data_volume
        dsl.child_object "env_db_url", env_db_url
        dsl.child_object "primary_database", primary_database
        dsl.child_object "config_node", config_node
        extra_depends_on.each do |realized_node|
          dsl.child_object "Extra depends_on #{realized_node.name}", realized_node
        end
        dsl.env_vars env_vars
      end
    end
  end
end
