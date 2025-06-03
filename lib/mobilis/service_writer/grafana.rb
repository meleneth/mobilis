module Mobilis
  module ServiceWriter
    class Grafana < Mobilis::Base::ServiceWriter
      def datasources
        data = Mobilis::AutoVivify.new
        data["apiVersion"] = 1
        datasource = AutoVivify.new
        datasource["name"] = "Prometheus"
        datasource["type"] = "prometheus"
        datasource["uid"] = "prometheus_ds"
        datasource["access"] = "proxy"
        datasource["url"] = "http://prometheus:9090"
        datasource["isDefault"] = false
        datasource["jsonData"]["timeInterval"] = "30s"
        data["datasources"] << datasource

        data
      end

      def write
        Dir.mkdir "provisioning"
        Dir.chdir "provisioning"
        Dir.mkdir "datasources"
        Dir.chdir "datasources"
        File.write("prometheus.yml", ::YAML.dump(Mobilis::YAML.deep_stringify_keys(datasources.to_serial)))
      end
    end
  end
end
