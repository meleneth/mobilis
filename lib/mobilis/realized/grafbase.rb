# frozen_string_literal: true

module Mobilis
  module Realized
    class Grafbase < Mobilis::Base::ImageForm
      attr_reader :subgraphs, :collector

      def initialize(env, node)
        super(env, node, Mobilis::ContainerVersions::GRAFBASE_GATEWAY)
        @has_service_dir = true
        register_external_port(5000, "#{name}_WEB_PORT", "#{name} federated GraphQL port")
        add_volume("./#{name}/gateway.toml", "/etc/grafbase.toml:ro")
        add_volume("#{name}-schema", "/schema:ro")
        set_command("--config /etc/grafbase.toml --schema /schema/supergraph.graphql --listen-address 0.0.0.0:5000")
        set_healthcheck_command('wget -q -O /dev/null http://127.0.0.1:5000/health', interval: "5s", retries: 20,
                                start_period: "15s")
      end

      def exposed_port_no
        5000
      end

      def after_all_nodes_realized
        @subgraphs = extra_depends_on.filter_map do |edge|
          target = edge[:target]
          next if target.is_a?(Mobilis::Node::OtelCollector)

          provider = realized_env.realized_node_for_config_node(target)
          unless provider.is_a?(Mobilis::Realized::FastAPI) && provider.config_node.graphql_subgraph_name
            raise ArgumentError, "#{name} requires connected FastAPI GraphQL subgraphs"
          end
          provider
        end
        raise ArgumentError, "#{name} requires at least one GraphQL subgraph" if subgraphs.empty?
        names = subgraphs.map { |subgraph| subgraph.config_node.graphql_subgraph_name }
        raise ArgumentError, "#{name} has duplicate subgraph names" unless names.uniq == names

        collectors = connected_nodes(Mobilis::Realized::OtelCollector)
        raise ArgumentError, "#{name} supports one collector" if collectors.length > 1

        @collector = collectors.first
      end

      def service_writer
        Mobilis::ServiceWriter::Grafbase
      end

      def service_wrapped_compose
        wrapper = super
        composer_depends = subgraphs.to_h { |subgraph| [subgraph.name, {condition: "service_healthy"}] }
        composer = {
          build: {context: "./#{name}"},
          image: "#{meta_project_name}/#{name}-composer",
          command: ["/app/compose.sh"],
          volumes: ["#{name}-schema:/schema"],
          depends_on: composer_depends
        }
        wrapper[:services]["#{name}-composer"] = composer
        wrapper[:services][name][:depends_on]["#{name}-composer"] = {condition: "service_completed_successfully"}
        wrapper[:volumes] = {"#{name}-schema" => {}}
        wrapper
      end
    end
  end
end
