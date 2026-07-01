# frozen_string_literal: true

module Mobilis
  module Realized
    class Loki < Mobilis::Base::ImageForm
      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::LOKI)
        @has_service_dir = true
        register_external_port(exposed_port_no, "#{name}_WEB_PORT", "#{name} web interface port")
        add_volume("./#{name}/loki-config.yaml", "/etc/loki/loki-config.yaml")
        compose[:command] << "-config.file=/etc/loki/loki-config.yaml"
      end

      def exposed_port_no
        3100
      end

      def service_writer
        Mobilis::ServiceWriter::Loki
      end
    end
  end
end
