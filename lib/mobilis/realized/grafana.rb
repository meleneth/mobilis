# frozen_string_literal: true

module Mobilis
  module Realized
    class Grafana < Mobilis::Base::ImageForm
      ADMIN_USER = "admin"
      ADMIN_PASSWORD = "mobilis-admin"

      def initialize(realized_env, config_node)
        super(realized_env, config_node, ContainerVersions::GRAFANA)
        @has_service_dir = true
        @has_data_volume = true
        @has_dockerfile = false
        add_volume("./data/#{environment}/#{name}", "/var/lib/grafana")
        add_volume("./#{name}/provisioning/datasources", "/etc/grafana/provisioning/datasources")
        add_compose_raw_var("GF_PATHS_PROVISIONING", "/etc/grafana/provisioning")
        add_compose_raw_var("GF_SECURITY_ADMIN_USER", ADMIN_USER)
        add_compose_raw_var("GF_SECURITY_ADMIN_PASSWORD", ADMIN_PASSWORD)
        register_external_port(exposed_port_no, "#{name}_WEB_PORT",
                               "#{name} web interface port")
        compose[:user] = "${HOST_UID}:${HOST_GID}"
      end

      def exposed_port_no
        3000
      end

      def after_all_nodes_realized
        loki = realized_env.find_realized_node_by_name("loki")
        register_depends_on(loki) if loki
      end

      def dependant_services_require_restart?
        true
      end

      def service_writer
        Mobilis::ServiceWriter::Grafana
      end
    end
  end
end
