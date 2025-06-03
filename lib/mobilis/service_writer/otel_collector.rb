module Mobilis
  module ServiceWriter
    class OtelCollector < Mobilis::Base::ServiceWriter
      def otel_collector
        return @otel_collector if defined? @otel_collector

        @otel_collector = Mobilis::AutoVivify.new
        protocols = @otel_collector["receivers"]["otlp"]["protocols"]
        protocols["grpc"]
        protocols["http"]
        @otel_collector["processors"]
        @otel_collector["exporters"]
        @otel_collector["service"]["pipelines"]
        @otel_collector
      end

      def write
        File.write("otel-collector-config.yml",
                   ::YAML.dump(Mobilis::YAML.deep_stringify_keys(otel_collector.to_serial)))
      end
    end
  end
end
