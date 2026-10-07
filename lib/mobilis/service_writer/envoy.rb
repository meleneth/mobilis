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
        # @type var action: Hash[Symbol, untyped]
        action = if authoritative.size == 1
          {cluster: authoritative.first[:backend].name}
        else
          {weighted_clusters: {runtime_key_prefix: "migration.authority", clusters: authoritative.map { |r| {name: r[:backend].name, weight: r[:weight]} }}}
        end
        # Keep a mirror policy even at zero so runtime can enable it later.
        mirror = routes.find { |r| r[:mirror_only] } || authoritative[1]
        if mirror
          action[:request_mirror_policies] = [{cluster: mirror[:backend].name,
                                               runtime_fraction: {runtime_key: "migration.mirror",
                                                                  default_value: {numerator: mirror[:mirror_percent], denominator: "HUNDRED"}}}]
        end
        # @type var manager: Hash[String | Symbol, untyped]
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
        collector = realized_node.collector
        if collector
          clusters << cluster("mobilis_otel", collector.name, collector.grpc_port, http2: true)
          manager[:tracing] = {
            provider: {name: "envoy.tracers.opentelemetry", typed_config: {
              "@type" => "type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig",
              :grpc_service => {envoy_grpc: {cluster_name: "mobilis_otel"}}, :service_name => realized_node.name
            }}, random_sampling: {value: 100}
          }
        end
        # @type var config: Hash[Symbol, untyped]
        config = {static_resources: {
          listeners: [{name: "http", address: address("0.0.0.0", realized_node.exposed_port_no),
                       filter_chains: [{filters: [{name: "envoy.filters.network.http_connection_manager", typed_config: manager}]}]}],
          clusters: clusters
        }}
        if authoritative.size > 1
          # @type var admin_layer: Hash[String, String]
          admin_layer = {}
          admin_port = (realized_node.exposed_port_no == 9901) ? 9902 : 9901
          config[:admin] = {address: address("0.0.0.0", admin_port)}
          config[:layered_runtime] = {layers: [{name: "admin", admin_layer: admin_layer}]}
        end
        config
      end

      private

      def address(host, port)
        {socket_address: {address: host, port_value: port}}
      end

      def cluster(name, host, port, http2: false)
        # @type var config: Hash[Symbol, untyped]
        config = {name: name, type: "STRICT_DNS", connect_timeout: "5s", lb_policy: "ROUND_ROBIN",
                  load_assignment: {cluster_name: name, endpoints: [{lb_endpoints: [{endpoint: {address: address(host, port)}}]}]}}
        if http2
          # @type var http2_options: Hash[String, String]
          http2_options = {}
          config[:typed_extension_protocol_options] = {
            "envoy.extensions.upstreams.http.v3.HttpProtocolOptions" => {
              "@type" => "type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions",
              :explicit_http_config => {http2_protocol_options: http2_options}
            }
          }
        end
        config
      end
    end
  end
end
