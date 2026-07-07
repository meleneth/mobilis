# frozen_string_literal: true

module Mobilis
  module Realized
    class Alloy < Mobilis::Base::ImageForm
      attr_reader :loki

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::ALLOY)
        @has_service_dir = true
        add_volume("./#{name}/config.alloy", "/etc/alloy/config.alloy")
        add_volume("/var/run/docker.sock", "/var/run/docker.sock:ro")
        compose[:command] << "run"
        compose[:command] << "/etc/alloy/config.alloy"
        compose[:command] << "--server.http.listen-addr=0.0.0.0:12345"
        compose[:command] << "--storage.path=/var/lib/alloy/data"
      end

      def after_all_nodes_realized
        loki_config = config_node.loki
        @loki = realized_env.realized_node_for_config_node(loki_config) if loki_config
        @loki ||= realized_env.find_realized_node_by_name("loki")
        loki = @loki
        register_depends_on(loki) if loki
      end

      def exposed_port_no
        12345
      end

      def service_writer
        Mobilis::ServiceWriter::Alloy
      end
    end
  end
end
