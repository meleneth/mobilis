# frozen_string_literal: true

module Mobilis
  module Realized
    class Promtail < Mobilis::Base::ImageForm
      attr_reader :loki

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::PROMTAIL)
        @has_service_dir = true
        add_volume("./#{name}/promtail-config.yaml", "/etc/promtail/promtail-config.yaml")
        add_volume("/var/run/docker.sock", "/var/run/docker.sock:ro")
        compose[:command] << "-config.file=/etc/promtail/promtail-config.yaml"
      end

      def after_all_nodes_realized
        @loki = realized_env.realized_node_for_config_node(config_node.loki) if config_node.loki
        @loki ||= realized_env.find_realized_node_by_name("loki")
        register_depends_on(@loki) if @loki
      end

      def exposed_port_no
        9080
      end

      def service_writer
        Mobilis::ServiceWriter::Promtail
      end
    end
  end
end
