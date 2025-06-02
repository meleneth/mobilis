# frozen_string_literal: true

module Mobilis
  module Realized
    class Grafana < Mobilis::Base::ImageForm
      def initialize(realized_env, config_node)
        super(realized_env, config_node, ContainerVersions::GRAFANA)
        @has_service_dir = true
        @has_data_volume = true
        @has_dockerfile = false
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
