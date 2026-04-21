# frozen_string_literal: true

module Mobilis
  module Realized
    class GoAws < Mobilis::Base::ImageForm
      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::GOAWS)

        @has_data_volume = true
        @has_service_dir = true

        # Persistent state
        add_volume("./#{name}/data", "/data")

        # Config file
        add_volume("./#{name}/goaws.yaml", "/etc/goaws/goaws.yaml")

        register_external_port(
          exposed_port_no,
          "#{name}_WEB_PORT",
          "#{name} goaws endpoint port"
        )
      end

      def exposed_port_no
        4100
      end

      def dependant_services_require_restart?
        true
      end

      def service_writer
        Mobilis::ServiceWriter::GoAws
      end
    end
  end
end

