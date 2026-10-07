# frozen_string_literal: true

module Mobilis
  module ServiceWriter
    class Envoy < Mobilis::Base::ServiceWriter
      def write
        Mobilis::YAMLWriter.write_yaml("envoy.yaml", configuration)
        realized_node.each_model_of_type(Mobilis::Model::File, &:write_file)
      end

      def configuration
        routes = realized_node.routes
        authoritative = routes.reject { |r| r[:mirror_only] }
        action = if authoritative.size == 1
          {cluster: authoritative.first[:backend].name}
        else
          {weighted_clusters: {runtime_key_prefix: "migration.authority", clusters: authoritative.map { |r| {name: r[:backend].name, weight: r[:weight]} }}}
        end
        mirrors = routes.select { |r| r[:mirror_percent] > 0 || r[:mirror_only] || (routes.size > 1 && r == routes[1] && routes.none? { |edge| edge[:mirror_only] }) }.map do |route|
          {cluster: route[:backend].name,
           runtime_fraction: {runtime_key: "migration.mirror", default_value: {numerator: route[:mirror_percent], denominator: "HUNDRED"}}}
        end
        action[:request_mirror_policies] = mirrors unless mirrors.empty?
        manager = {
          "@type" => "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
          :stat_prefix => "ingress_http",
          :route_config => {name: "default", virtual_hosts: [{name: "services", domains: ["*"],
                                                              routes: [{match: {prefix: "/"}, route: action}]}]},
          :http_filters => [{name: "envoy.filters.http.router", typed_config: {
            "@type" => "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
          }}]
        }
        clusters = routes.map { |r| cluster(r[:backend].name, r[:backend].name, r[:backend].exposed_port_no) }
        if realized_node.collector
          collector = realized_node.collector
          clusters << cluster("mobilis_otel", collector.name, collector.grpc_port, http2: true)
          manager[:tracing] = {
            provider: {name: "envoy.tracers.opentelemetry", typed_config: {
              "@type" => "type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig",
              :grpc_service => {envoy_grpc: {cluster_name: "mobilis_otel"}}, :service_name => realized_node.name
            }}, random_sampling: {value: 100}
          }
        end
        {admin: {address: address("0.0.0.0", 9901)},
         layered_runtime: {layers: [{name: "admin", admin_layer: {}}]},
         static_resources: {
           listeners: [{name: "http", address: address("0.0.0.0", realized_node.exposed_port_no),
                        filter_chains: [{filters: [{name: "envoy.filters.network.http_connection_manager", typed_config: manager}]}]}],
           clusters: clusters
         }}
      end

      private

      def address(host, port)
        {socket_address: {address: host, port_value: port}}
      end

      def cluster(name, host, port, http2: false)
        config = {name: name, type: "STRICT_DNS", connect_timeout: "5s", lb_policy: "ROUND_ROBIN",
                  load_assignment: {cluster_name: name, endpoints: [{lb_endpoints: [{endpoint: {address: address(host, port)}}]}]}}
        if http2
          config[:typed_extension_protocol_options] = {
            "envoy.extensions.upstreams.http.v3.HttpProtocolOptions" => {
              "@type" => "type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions",
              :explicit_http_config => {http2_protocol_options: {}}
            }
          }
        end
        config
      end
    end
  end
end
