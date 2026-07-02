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
        s3_storage_nodes.each do |node|
          storage_scrape = Mobilis::AutoVivify.new
          storage_scrape["job_name"] = "#{node.name}_seaweedfs"
          storage_static_config = Mobilis::AutoVivify.new
          storage_static_config["targets"] = ["#{node.name}:#{Mobilis::Realized::S3Storage::METRICS_PORT}"]
          storage_scrape["static_configs"] << storage_static_config
          data["scrape_configs"] << storage_scrape
        end

        data
      end

      def write
        File.write("prometheus.yml", ::YAML.dump(Mobilis::YAML.deep_stringify_keys(datasources.to_serial)))
      end

      private

      def s3_storage_nodes
        realized_env.realized_nodes.select do |node|
          node.is_a?(Mobilis::Realized::S3Storage) && node.observability_enabled?
        end
      end
    end
  end
end
