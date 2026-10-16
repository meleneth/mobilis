# frozen_string_literal: true

module Mobilis
  module ServiceWriter
    class Grafbase < Mobilis::Base::ServiceWriter
      def write
        File.write("Dockerfile", <<~DOCKER)
          FROM node:22-bookworm-slim
          RUN npm install --global grafbase@#{Mobilis::ContainerVersions::GRAFBASE_CLI}
          WORKDIR /app
          COPY compose.toml compose.sh /app/
        DOCKER
        File.write("compose.toml", realized_node.subgraphs.map do |subgraph|
          name = subgraph.config_node.graphql_subgraph_name
          endpoint = "http://#{subgraph.name}:#{subgraph.exposed_port_no}/graphql"
          "[subgraphs.#{name}]\nintrospection_url = #{endpoint.inspect}\nurl = #{endpoint.inspect}\n"
        end.join("\n"))
        File.write("compose.sh", <<~'SHELL')
          #!/bin/sh
          set -eu
          grafbase compose --config /app/compose.toml > /schema/supergraph.graphql.tmp || {
            echo "Grafbase schema composition failed; inspect the subgraph SDL and the diagnostics above" >&2
            exit 1
          }
          test -s /schema/supergraph.graphql.tmp || {
            echo "Grafbase produced an empty supergraph schema" >&2
            exit 1
          }
          mv /schema/supergraph.graphql.tmp /schema/supergraph.graphql
        SHELL
        File.chmod(0o755, "compose.sh")
        telemetry = if realized_node.collector
                      <<~TOML
                        [telemetry.exporters.otlp]
                        enabled = true
                        endpoint = "#{realized_node.collector.internal_url}"
                        protocol = "http"

                        [telemetry.tracing]
                        sampling = 1

                        [telemetry.tracing.propagation]
                        trace_context = true
                      TOML
                    else
                      ""
                    end
        File.write("gateway.toml", telemetry)
      end
    end
  end
end
