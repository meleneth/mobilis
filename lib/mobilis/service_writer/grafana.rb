require "fileutils"
require "json"

module Mobilis
  module ServiceWriter
    class Grafana < Mobilis::Base::ServiceWriter
      def datasources
        data = Mobilis::AutoVivify.new
        data["apiVersion"] = 1
        datasource_nodes.each do |node|
          data["datasources"] << Mobilis::YAML.deep_stringify_keys(datasource_for(node))
        end
        data
      end

      def dashboard_provider
        {
          apiVersion: 1,
          providers: [
            {
              name: "Mobilis",
              orgId: 1,
              folder: "Mobilis",
              type: "file",
              disableDeletion: false,
              updateIntervalSeconds: 10,
              allowUiUpdates: true,
              options: {
                path: "/etc/grafana/provisioning/dashboards"
              }
            }
          ]
        }
      end

      def dashboards
        {
          "mobilis-overview.json" => overview_dashboard,
          "mobilis-filtered-activeresource.json" => filtered_active_resource_dashboard
        }.reject { |_filename, dashboard| dashboard[:panels].empty? }
      end

      def write
        FileUtils.mkdir_p("../data")
        FileUtils.mkdir_p("../data/test")
        FileUtils.mkdir_p("../data/test/grafana")
        FileUtils.mkdir_p("../data/development")
        FileUtils.mkdir_p("../data/development/grafana")
        FileUtils.mkdir_p("../data/production")
        FileUtils.mkdir_p("../data/production/grafana")
        FileUtils.mkdir_p "provisioning/datasources"
        FileUtils.mkdir_p "provisioning/dashboards"

        File.write("provisioning/datasources/mobilis.yml",
                   ::YAML.dump(Mobilis::YAML.deep_stringify_keys(datasources.to_serial)))
        File.write("provisioning/dashboards/mobilis.yml",
                   ::YAML.dump(Mobilis::YAML.deep_stringify_keys(dashboard_provider)))
        dashboards.each do |filename, dashboard|
          File.write("provisioning/dashboards/#{filename}", JSON.pretty_generate(dashboard))
        end
      end

      private

      def datasource_nodes
        realized_env.realized_nodes.select do |node|
          [
            Mobilis::Realized::Prometheus,
            Mobilis::Realized::Loki,
            Mobilis::Realized::Jaeger,
            Mobilis::Realized::PostgreSQL,
            Mobilis::Realized::MySQL
          ].any? { |klass| node.is_a?(klass) }
        end
      end

      def datasource_for(node)
        case node
        when Mobilis::Realized::Prometheus
          prometheus_datasource(node)
        when Mobilis::Realized::Loki
          loki_datasource(node)
        when Mobilis::Realized::Jaeger
          jaeger_datasource(node)
        when Mobilis::Realized::PostgreSQL
          postgres_datasource(node)
        when Mobilis::Realized::MySQL
          mysql_datasource(node)
        else
          raise "Unsupported Grafana datasource node #{node.class}"
        end
      end

      def prometheus_datasource(node)
        {
          name: "Prometheus",
          type: "prometheus",
          uid: datasource_uid(node, "prometheus"),
          access: "proxy",
          url: "http://#{node.name}:#{node.exposed_port_no}",
          isDefault: true,
          jsonData: {
            timeInterval: "30s"
          }
        }
      end

      def loki_datasource(node)
        {
          name: "Loki",
          type: "loki",
          uid: datasource_uid(node, "loki"),
          access: "proxy",
          url: "http://#{node.name}:#{node.exposed_port_no}",
          isDefault: false
        }
      end

      def jaeger_datasource(node)
        {
          name: "Jaeger",
          type: "jaeger",
          uid: datasource_uid(node, "jaeger"),
          access: "proxy",
          url: "http://#{node.name}:#{node.exposed_port_no}",
          isDefault: false
        }
      end

      def postgres_datasource(node)
        {
          name: "PostgreSQL #{node.name}",
          type: "postgres",
          uid: datasource_uid(node, "postgres"),
          access: "proxy",
          url: "#{node.name}:#{node.internal_port_no}",
          user: node.user,
          isDefault: false,
          jsonData: {
            database: node.db_name,
            sslmode: "disable"
          },
          secureJsonData: {
            password: node.password
          }
        }
      end

      def mysql_datasource(node)
        {
          name: "MySQL #{node.name}",
          type: "mysql",
          uid: datasource_uid(node, "mysql"),
          access: "proxy",
          url: "#{node.name}:#{node.internal_port_no}",
          user: node.user,
          isDefault: false,
          jsonData: {
            database: node.db_name
          },
          secureJsonData: {
            password: node.password
          }
        }
      end

      def overview_dashboard
        panels = []
        panels << markdown_panel(1, "Generated services", service_inventory_markdown, 0, 0, 8, 8)
        panels.concat(service_log_panels)
        panels.concat(database_panels)
        panels.concat(s3_storage_panels)

        dashboard("mobilis-overview", "Mobilis Overview", panels, ["mobilis", realized_env.environment.to_s])
      end

      def filtered_active_resource_dashboard
        resources = filtered_resources
        panels = resources.map.with_index do |resource, index|
          markdown_panel(
            index + 1,
            "#{resource[:service]} #{resource[:model]}",
            filtered_resource_markdown(resource),
            (index % 2) * 12,
            (index / 2) * 8,
            12,
            8
          )
        end

        dashboard("mobilis-filtered-activeresource", "Filtered ActiveResource Affordances", panels,
                  ["mobilis", "filtered-activeresource"])
      end

      def service_log_panels
        return [] unless loki_datasource?

        loggable_nodes.map.with_index do |node, index|
          logs_panel(
            100 + index,
            "#{node.name} logs",
            "{container=~\".*#{node.name}.*\"}",
            (index % 2) * 12,
            8 + (index / 2) * 8
          )
        end
      end

      def s3_storage_panels
        return [] unless prometheus_datasource?

        s3_storage_nodes.map.with_index do |node, index|
          timeseries_panel(
            300 + index,
            "#{node.name} SeaweedFS up",
            "up{job=\"#{node.name}_seaweedfs\"}",
            (index % 2) * 12,
            24 + (index / 2) * 8
          )
        end
      end

      def database_panels
        return [] unless prometheus_datasource?

        database_nodes.map.with_index do |node, index|
          timeseries_panel(
            200 + index,
            "#{node.name} up",
            "up{job=~\".*#{node.name}.*\"}",
            (index % 2) * 12,
            16 + (index / 2) * 8
          )
        end
      end

      def service_inventory_markdown
        rows = realized_env.realized_nodes.map do |node|
          "- #{node.name} (#{node.class.name.split('::').last})"
        end

        rows.join("\n")
      end

      def filtered_resource_markdown(resource)
        filters = resource[:filterable_fields].empty? ? "none declared" : resource[:filterable_fields].join(", ")

        [
          "- Service: #{resource[:service]}",
          "- Model: #{resource[:model]}",
          "- Filter fields: #{filters}",
          "- Primary database: #{resource[:database] || 'none'}"
        ].join("\n")
      end

      def filtered_resources
        rails_nodes.flat_map do |node|
          node.config_node.models.select { |model| model.respond_to?(:api_exposed?) && model.api_exposed? }.map do |model|
            {
              service: node.name,
              model: model.name,
              filterable_fields: model.filterable_fields,
              database: node.primary_database&.name
            }
          end
        end
      end

      def rails_nodes
        @rails_nodes ||= realized_env.realized_nodes.select { |node| node.is_a?(Mobilis::Realized::Rails) }
      end

      def database_nodes
        @database_nodes ||= realized_env.realized_nodes.select do |node|
          node.is_a?(Mobilis::Realized::PostgreSQL) || node.is_a?(Mobilis::Realized::MySQL)
        end
      end

      def s3_storage_nodes
        @s3_storage_nodes ||= realized_env.realized_nodes.select do |node|
          node.is_a?(Mobilis::Realized::S3Storage) && node.observability_enabled?
        end
      end

      def loggable_nodes
        rails_nodes + s3_storage_nodes
      end

      def prometheus_datasource?
        datasource_nodes.any? { |node| node.is_a?(Mobilis::Realized::Prometheus) }
      end

      def loki_datasource?
        datasource_nodes.any? { |node| node.is_a?(Mobilis::Realized::Loki) }
      end

      def datasource_uid(node, suffix)
        "#{node.name.gsub(/[^a-zA-Z0-9_-]/, "-")}_#{suffix}_ds"
      end

      def dashboard(uid, title, panels, tags)
        {
          uid: uid,
          title: title,
          tags: tags,
          timezone: "browser",
          schemaVersion: 39,
          version: 1,
          refresh: "30s",
          panels: panels
        }
      end

      def markdown_panel(id, title, markdown, x, y, w, h)
        {
          id: id,
          title: title,
          type: "text",
          gridPos: { h: h, w: w, x: x, y: y },
          options: {
            mode: "markdown",
            content: markdown
          }
        }
      end

      def logs_panel(id, title, expr, x, y)
        {
          id: id,
          title: title,
          type: "logs",
          datasource: { type: "loki", uid: "loki_loki_ds" },
          gridPos: { h: 8, w: 12, x: x, y: y },
          targets: [
            {
              refId: "A",
              expr: expr
            }
          ]
        }
      end

      def timeseries_panel(id, title, expr, x, y)
        {
          id: id,
          title: title,
          type: "timeseries",
          datasource: { type: "prometheus", uid: "prometheus_prometheus_ds" },
          gridPos: { h: 8, w: 12, x: x, y: y },
          targets: [
            {
              refId: "A",
              expr: expr
            }
          ]
        }
      end
    end
  end
end
