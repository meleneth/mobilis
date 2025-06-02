# frozen_string_literal: true

module Mobilis
  module Realized
    class Prometheus < Mobilis::Base::ImageForm
      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::PROMETHEUS)

        @has_data_volume = false
        @has_service_dir = true
      end

      def dependant_services_require_restart?
        true
      end

      def service_writer
        Mobilis::ServiceWriter::Prometheus
      end
    end
  end
end
