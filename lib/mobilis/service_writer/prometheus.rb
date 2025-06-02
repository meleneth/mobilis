module Mobilis
  module ServiceWriter
    class Prometheus < Mobilis::Base::ServiceWriter
      def datasources
        data = Mobilis::AutoVivify.new
        data["global"]["scrape_interval"] = "5s"
        scrape_config = Mobilis::AutoVivify.new
        scrape_config["job_name"] = "otel_collector"
        static_config = Mobilis::AutoVivify.new
        static_config["targets"] = ["otel-collector:9464"]
        scrape_config["static_configs"] << static_config
        data["scrape_configs"] << scrape_config
        data["apiVersion"] = 1

        data
      end

      def write
        File.write("prometheus.yml", ::YAML.dump(Mobilis::YAML.deep_stringify_keys(datasources)))
      end
    end
  end
end
