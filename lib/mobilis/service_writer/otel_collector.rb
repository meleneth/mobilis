module Mobilis
  module ServiceWriter
    class OtelCollector < Mobilis::Base::ServiceWriter
      def otel_collector
        return @otel_collector if defined? @otel_collector

        @otel_collector = Mobilis::AutoVivify.new
        protocols = @otel_collector["receivers"]["otlp"]["protocols"]
        protocols["grpc"]["endpoint"] = "0.0.0.0:4317"
        protocols["http"]["endpoint"] = "0.0.0.0:4318"

        @otel_collector["processors"]["batch"] = {}
        memory_limiter = @otel_collector["processors"]["memory_limiter"]
        memory_limiter["limit_mib"] = 500
        memory_limiter["spike_limit_mib"] = 100
        memory_limiter["check_interval"] = "5s"

        otlp_exporter = @otel_collector["exporters"]["otlp"]
        otlp_exporter["endpoint"] = "jaeger:4317" # YOU DID NOT JUST HARDCODE THIS SHIT TODO FUCKING TODO
        otlp_exporter["tls"]["insecure"] = true

        @otel_collector["exporters"]["prometheus"]["endpoint"] = "0.0.0.0:9464"

        traces = @otel_collector["service"]["pipelines"]["traces"]
        traces["receivers"] << "otlp"
        traces["processors"] << "batch"
        traces["processors"] << "memory_limiter"
        traces["exporters"] << "otlp"

        metrics = @otel_collector["service"]["pipelines"]["metrics"]
        metrics["receivers"] << "otlp"
        metrics["processors"] << "batch"
        metrics["exporters"] << "prometheus"

        @otel_collector
      end

      def write
        File.write("otel-collector-config.yaml",
                   ::YAML.dump(Mobilis::YAML.deep_stringify_keys(otel_collector.to_serial)))
      end
    end
  end
end
