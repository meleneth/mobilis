# frozen_string_literal: true

module Mobilis
  module Realized
    # Shared realization of the two HTTP application archetypes.
    class HTTPApplication < Mobilis::Base::BuildForm
      attr_reader :database, :collector

      def initialize(env, node)
        super
        @has_service_dir = true
        register_external_port(exposed_port_no, "#{name}_WEB_PORT", "#{name} HTTP port") if config_node.publish_port
        add_compose_raw_var("PORT", exposed_port_no)
      end

      def exposed_port_no
        config_node.port
      end

      def after_all_nodes_realized
        databases = connected_nodes(Mobilis::Realized::SQLDatabase)
        raise ArgumentError, "#{name} supports one PostgreSQL connection" if databases.length > 1 || databases.any? { |db| !db.is_a?(Mobilis::Realized::PostgreSQL) }

        @database = databases.first
        add_compose_aliased_var("DATABASE_URL", "#{name}_database_url", database.url) if database
        collectors = connected_nodes(Mobilis::Realized::OtelCollector)
        raise ArgumentError, "#{name} supports one collector" if collectors.length > 1

        @collector = collectors.first
        return unless collector

        add_compose_raw_var("OTEL_SERVICE_NAME", name)
        add_compose_raw_var("OTEL_EXPORTER_OTLP_ENDPOINT", collector.internal_url)
        add_compose_raw_var("OTEL_EXPORTER_OTLP_PROTOCOL", "http/protobuf")
        add_compose_raw_var("OTEL_PROPAGATORS", "tracecontext,baggage")
      end

      def otel_enabled?
        !collector.nil?
      end
    end
  end
end
