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
        register_depends_on(@primary_database)
        db_env_db_url = @primary_database&.env_db_url
        if db_env_db_url
          @env_db_url = add_compose_aliased_var("DATABASE_URL",
                                                db_env_db_url.envfile_name,
                                                db_env_db_url.value)
        end
        add_compose_raw_var("RAILS_ENV", environment.to_s)
        add_compose_raw_var("RAILS_MIN_THREADS", 5)
        add_compose_raw_var("RAILS_MAX_THREADS", 5)
        register_external_port(exposed_port_no, "#{name}_WEB_PORT",
                               "#{name} web interface port")
      end

      def exposed_port_no
        3000
      end

      def required_plugins
        [
          Mobilis::Plugin::RailsBuilder,
          Mobilis::Plugin::RailsCreateModels,
          Mobilis::Plugin::RailsDBFanout,
          Mobilis::Plugin::RailsDBLibSupport,
          Mobilis::Plugin::RailsTestMountSourceVolume
        ]
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
        dsl.child_object "config_node", config_node
        extra_depends_on.each do |realized_node|
          dsl.child_object "Extra depends_on #{realized_node.name}", realized_node
        end
        dsl.env_vars env_vars
      end
    end
  end
end
