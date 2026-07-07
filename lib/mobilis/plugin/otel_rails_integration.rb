# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin creates rails models defined on rails services
    class OTELRailsIntegration < Mobilis::Base::RealizedNodePlugin
      def rails_builder
        builder = manifest.plugin_for Mobilis::Plugin::RailsBuilder
        raise "RailsBuilder plugin is required to install OTEL" unless builder.is_a?(Mobilis::Plugin::RailsBuilder)

        builder
      end

      def hook_after_services_written
        directory_service.chdir_project(realized_node)
        rails_builder.container_run("bundle add opentelemetry-sdk opentelemetry-instrumentation-all opentelemetry-exporter-otlp")
        write_instrumentation_rb
        write_opentelemetry_initializer
        write_structured_logging_initializer
        commit_all("#{realized_node.name} - OTEL integration")
      end

      def write_instrumentation_rb
        File.write("lib/instrumentation.rb", <<~HERE)
          module Instrumentation
            def self.trace(name, attributes: {}, &block)
              safe_attrs = attributes.transform_keys(&:to_s)
              tracer = OpenTelemetry.tracer_provider.tracer("#{realized_node.name}")
              tracer.in_span(name, attributes: safe_attrs, &block)
            end
          end
        HERE
      end

      def write_opentelemetry_initializer
        File.write("config/initializers/opentelemetry.rb", <<~HERE)
          require "opentelemetry/sdk"
          require "opentelemetry/instrumentation/all"


          OpenTelemetry::SDK.configure do |c|
            otel_endpoint =  "\#{ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")}/v1/traces"
            c.service_name = "#{realized_node.name}"
            c.use_all
            c.add_span_processor(
              OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
                OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: otel_endpoint)
              )
            )
          end
        HERE
      end

      def write_structured_logging_initializer
        File.write("config/initializers/structured_logging.rb", <<~RUBY)
          # frozen_string_literal: true

          require "json"
          require "logger"
          require "active_support/logger"
          require "active_support/tagged_logging"

          class MobilisJsonLogFormatter < Logger::Formatter
            def call(severity, time, progname, msg)
              event = {
                timestamp: time.utc.iso8601(6),
                severity: severity,
                service_name: "#{realized_node.name}",
                progname: progname,
                message: message_for(msg)
              }
              event.merge!(trace_context)
              "\#{JSON.generate(event)}\\n"
            end

            private

            def message_for(msg)
              case msg
              when String
                msg
              when Exception
                "\#{msg.class}: \#{msg.message}"
              else
                msg.inspect
              end
            end

            def trace_context
              return {} unless defined?(OpenTelemetry::Trace)

              span_context = OpenTelemetry::Trace.current_span.context
              return {} unless span_context&.valid?

              {
                trace_id: span_context.hex_trace_id,
                span_id: span_context.hex_span_id
              }
            end
          end

          logger = ActiveSupport::Logger.new($stdout)
          logger.formatter = MobilisJsonLogFormatter.new
          Rails.logger = ActiveSupport::TaggedLogging.new(logger)
          Rails.application.config.logger = Rails.logger
          Rails.application.config.log_tags = []
        RUBY
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
