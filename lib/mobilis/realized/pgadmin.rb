# frozen_string_literal: true

module Mobilis
  module Realized
    class Pgadmin < Mobilis::Base::ImageForm
      ADMIN_EMAIL = "admin@example.com"
      ADMIN_PASSWORD = "mobilis-admin"

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::PGADMIN)
        @has_service_dir = true
        add_compose_raw_var("PGADMIN_DEFAULT_EMAIL", ADMIN_EMAIL)
        add_compose_raw_var("PGADMIN_DEFAULT_PASSWORD", ADMIN_PASSWORD)
        add_compose_raw_var("PGADMIN_DISABLE_POSTFIX", "True")
        add_compose_raw_var("PGADMIN_REPLACE_SERVERS_ON_STARTUP", "True")
        add_compose_raw_var("PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED", "False")
        add_volume("./#{name}/servers.json", "/pgadmin4/servers.json")
        register_external_port(exposed_port_no, "#{name}_WEB_PORT",
                               "#{name} web interface port")
      end

      def exposed_port_no
        80
      end

      def after_all_nodes_realized
        databases.each { |database| register_depends_on(database) }
      end

      def databases
        config_node.databases.map do |database|
          realized_database = realized_env.realized_node_for_config_node(database)
          unless realized_database.is_a?(Mobilis::Realized::SQLDatabase)
            raise Mobilis::NoSuchNode, "No realized database for #{database.name}"
          end

          realized_database
        end
      end

      def service_writer
        Mobilis::ServiceWriter::Pgadmin
      end

      def dependant_services_require_restart?
        true
      end
    end
  end
end
