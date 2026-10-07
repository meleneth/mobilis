# frozen_string_literal: true

module Mobilis
  module Realized
    class Envoy < Mobilis::Base::ImageForm
      attr_reader :collector, :routes

      def initialize(env, node)
        super(env, node, Mobilis::ContainerVersions::ENVOY)
        @has_service_dir = true
        add_volume("./#{name}/envoy.yaml", "/etc/envoy/envoy.yaml")
        set_command("-c /etc/envoy/envoy.yaml")
        register_external_port(exposed_port_no, "#{name}_WEB_PORT", "#{name} HTTP proxy port")
      end

      def exposed_port_no
        config_node.port
      end

      def after_all_nodes_realized
        @routes = extra_depends_on.filter_map do |edge|
          settings = edge[:http_route]
          next unless settings

          target = edge[:target]
          raise ArgumentError, "HTTP route requires a config backend" unless target.is_a?(Mobilis::Base::Node)

          backend = realized_env.realized_node_for_config_node(target)
          unless backend && backend.internal_url_scheme == "http" && backend.respond_to?(:exposed_port_no)
            raise ArgumentError, "HTTP route requires an HTTP backend"
          end
          [:weight, :mirror_percent].each do |key|
            value = settings[key]
            raise ArgumentError, "Invalid route #{key}" unless value.is_a?(Integer) && (0..100).cover?(value)
          end
          settings.merge(backend: backend)
        end
        if routes.empty?
          backends = connected_nodes(Mobilis::Base::RealizedNode).select do |backend|
            !backend.is_a?(Mobilis::Realized::OtelCollector) &&
              backend.internal_url_scheme == "http" && backend.respond_to?(:exposed_port_no)
          end
          @routes = [{backend: backends.first, weight: 100, mirror_percent: 0}] if backends.size == 1
        end
        raise ArgumentError, "Envoy requires a default HTTP route totaling 100" unless routes.any? && routes.sum { |r| r[:weight] } == 100
        authoritative = routes.reject { |route| route[:mirror_only] }
        shadows = routes.select { |route| route[:mirror_only] }
        unless authoritative.sum { |route| route[:weight] } == 100 && shadows.all? { |route| route[:weight].zero? }
          raise ArgumentError, "Mirror-only backends cannot carry authoritative weight"
        end
        raise ArgumentError, "Envoy supports one mirror-only backend" if shadows.size > 1
        raise ArgumentError, "Duplicate route backend" unless routes.map { |r| r[:backend].name }.uniq.size == routes.size

        collectors = connected_nodes(Mobilis::Realized::OtelCollector)
        raise ArgumentError, "Envoy supports one collector" if collectors.size > 1

        @collector = collectors.first
      end

      def service_writer
        Mobilis::ServiceWriter::Envoy
      end
    end
  end
end
