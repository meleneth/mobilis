# frozen_string_literal: true

module Mobilis
  module Realized
    class OtelCollector < Mobilis::Base::ImageForm
      attr_reader :otel_url

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::OTEL_COLLECTOR)
        @otel_url = add_env_only_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")

        @has_data_volume = false
        @has_service_dir = true
      end

      def dependant_services_require_restart?
        true
      end

      def service_writer
        Mobilis::ServiceWriter::OtelCollector
      end
    end
  end
end
