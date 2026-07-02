# frozen_string_literal: true

module Mobilis
  module Realized
    class Rack < Mobilis::Base::BuildForm
      INTERNAL_PORT = 9292

      def initialize(realized_env, config_node)
        super(realized_env, config_node)
        @has_service_dir = true
        @has_data_volume = false
        set_compose_build_context("./")
        compose[:build][:dockerfile] = "./#{name}/Dockerfile"
        register_external_port(INTERNAL_PORT, "#{name}_WEB_PORT", "#{name} web interface port")
        add_compose_raw_var("RACK_ENV", environment.to_s)
      end

      def after_all_nodes_realized
        add_otel_env if otel_enabled?
      end

      def exposed_port_no
        INTERNAL_PORT
      end

      def instance_count
        config_node.instances.to_i
      end

      def instance_names
        return [name] if instance_count <= 1

        [name] + (2..instance_count).map { |index| "#{name.sub(/service\z/, "")}#{index}service" }
      end

      def otel_enabled?
        extra_depends_on.any? do |dependency|
          target = dependency[:target]
          target.is_a?(Mobilis::Node::OtelCollector) ||
            target.is_a?(Mobilis::Realized::OtelCollector)
        end
      end

      def service_writer
        Mobilis::ServiceWriter::Rack
      end

      def service_wrapped_compose
        base = compose.clean_shrunk
        services = { name => base }
        instance_names.drop(1).each do |instance_name|
          instance_compose = Marshal.load(Marshal.dump(base))
          instance_compose.delete(:ports)
          services[instance_name] = instance_compose
        end
        { services: services }
      end

      private

      def add_otel_env
        add_compose_raw_var("OTEL_SERVICE_NAME", name)
        add_compose_raw_var("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")
        add_compose_raw_var("OTEL_TRACES_EXPORTER", "otlp")
        add_compose_raw_var("OTEL_METRICS_EXPORTER", "none")
        add_compose_raw_var("OTEL_LOGS_EXPORTER", "none")
      end
    end
  end
end
