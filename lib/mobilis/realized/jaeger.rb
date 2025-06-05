# frozen_string_literal: true

module Mobilis
  module Realized
    class Jaeger < Mobilis::Base::ImageForm
      attr_reader :jaeger_endpoint

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::JAEGER)
        # @jaeger_endpoint = add_env_only_var("JAEGER_ENDPOINT", "http://jaeger:14268/api/traces")
        # TODO figure out which which is which
        @jaeger_endpoint = "#{name}:4317"

        @has_data_volume = false
        @has_service_dir = false
        register_external_port(exposed_port_no, "#{name}_WEB_PORT",
                               "#{name} web interface port")
      end

      def exposed_port_no
        16_686
      end

      def dependant_services_require_restart?
        true
      end
    end
  end
end
