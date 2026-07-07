# frozen_string_literal: true

module Mobilis
  module Realized
    class OtelCollector < Mobilis::Base::ImageForm
      include Mobilis::PrettyPrint::PrettyPrintable
      attr_reader :otel_url

      def initialize(realized_env, config_node)
        super(realized_env, config_node, Mobilis::ContainerVersions::OTEL_COLLECTOR)
        @otel_url = add_env_only_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")

        @has_data_volume = false
        @has_service_dir = true
        add_volume("./#{name}/otel-collector-config.yaml", "/etc/otel-collector-config.yaml")
        set_command("--config=/etc/otel-collector-config.yaml")
        register_external_port(exposed_port_no, "#{name}_COLLECTOR_PORT",
                               "#{name} collector port")
      end

      def exposed_port_no
        4318 # http listener port
      end

      def prometheus_scrape_value
        "#{name}:9464"
      end

      def dependant_services_require_restart?
        true
      end

      def service_writer
        Mobilis::ServiceWriter::OtelCollector
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "environment", environment
        dsl.instance_value "has_service_dir", has_service_dir
        dsl.instance_value "has_data_volume", has_data_volume
        dsl.child_object "config_node", config_node
        extra_depends_on.each do |dependency|
          target = dependency[:target]
          next unless target.is_a?(Mobilis::Base::Node) || target.is_a?(Mobilis::Base::RealizedNode)

          dsl.child_object "Extra depends_on #{target.name}", target
        end
      end
    end
  end
end
