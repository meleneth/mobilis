# frozen_string_literal: true

require "digest"

module Mobilis
  module Browser
    class Topology
      Node = Data.define(
        :id, :service_id, :type, :name, :label, :category,
        :source_id, :start_offset, :end_offset
      )
      Edge = Data.define(:from, :to, :relationship)

      TYPE_METADATA = {
        "Mobilis::Node::Airflow" => ["Airflow", :application],
        "Mobilis::Node::Alloy" => ["Alloy", :observability],
        "Mobilis::Node::Cassandra" => ["Cassandra", :data],
        "Mobilis::Node::Envoy" => ["Envoy", :gateway],
        "Mobilis::Node::FastAPI" => ["FastAPI", :application],
        "Mobilis::Node::Flask" => ["Flask", :application],
        "Mobilis::Node::GoHTTP" => ["Go HTTP", :application],
        "Mobilis::Node::GoAws" => ["GoAWS", :application],
        "Mobilis::Node::GooglePubSub" => ["Google Pub/Sub", :messaging],
        "Mobilis::Node::Grafana" => ["Grafana", :observability],
        "Mobilis::Node::Grafbase" => ["Grafbase", :gateway],
        "Mobilis::Node::Jaeger" => ["Jaeger", :observability],
        "Mobilis::Node::Kafka" => ["Kafka", :messaging],
        "Mobilis::Node::Localstack" => ["LocalStack", :infrastructure],
        "Mobilis::Node::Loki" => ["Loki", :observability],
        "Mobilis::Node::MySQL" => ["MySQL", :data],
        "Mobilis::Node::OtelCollector" => ["OTel Collector", :observability],
        "Mobilis::Node::Pgadmin" => ["pgAdmin", :infrastructure],
        "Mobilis::Node::PostgreSQL" => ["PostgreSQL", :data],
        "Mobilis::Node::Prometheus" => ["Prometheus", :observability],
        "Mobilis::Node::Rack" => ["Rack", :application],
        "Mobilis::Node::Rails" => ["Rails", :application],
        "Mobilis::Node::Redis" => ["Redis", :data],
        "Mobilis::Node::S3Storage" => ["S3 Storage", :data]
      }.freeze

      attr_reader :nodes, :edges

      def self.from_analysis(analysis)
        new(analysis.system, declarations: analysis.declarations)
      end

      def initialize(system, declarations: [])
        @system = system
        @declarations = declarations
        @nodes = build_nodes.freeze
        @edges = build_edges.freeze
      end

      def empty? = nodes.empty?

      def node(id)
        nodes.find { |candidate| candidate.id == id }
      end

      private

      attr_reader :system, :declarations

      def build_nodes
        declaration_index = declarations.group_by { |declaration| normalize_name(declaration.name) }
        occurrences = Hash.new(0)

        system.config_nodes.values.map do |service|
          type_name = service.class.name
          label, category = TYPE_METADATA.fetch(type_name) do
            [type_name.split("::").last, :infrastructure]
          end
          identity = [type_name, service.name]
          occurrence = occurrences[identity]
          occurrences[identity] += 1
          declaration = declaration_index.fetch(service.name, []).shift

          Node.new(
            id: safe_id(type_name, service.name, occurrence),
            service_id: service.id,
            type: type_name,
            name: service.name,
            label: "#{label}: #{service.name}",
            category:,
            source_id: declaration&.id,
            start_offset: declaration&.start_offset,
            end_offset: declaration&.end_offset
          )
        end.sort_by { |node| [node.name, node.type, node.id] }
      end

      def build_edges
        nodes_by_service_id = nodes.to_h { |node| [node.service_id, node] }
        results = []

        system.config_nodes.each_value do |service|
          from = nodes_by_service_id[service.id]
          next unless from

          service.extra_depends_on.each do |dependency|
            target = dependency[:target] || find_service(dependency[:name])
            add_edge(results, from, nodes_by_service_id[target&.id], explicit_relationship(dependency))
          end

          reference_targets(service).each do |slot, target|
            add_edge(results, from, nodes_by_service_id[target.id], humanize(slot))
          end
        end

        results.uniq.sort_by { |edge| [edge.from, edge.to, edge.relationship.to_s] }
      end

      def reference_targets(service)
        singular = service.class.ref_attr_registry.flat_map do |slot|
          target = service.public_send(slot.name)
          target ? [[slot.name, target]] : []
        end
        plural = service.class.ref_list_registry.flat_map do |slot|
          Array(service.public_send(slot.name)).map { |target| [slot.name, target] }
        end
        singular + plural
      end

      def add_edge(results, from, to, relationship)
        return unless from && to

        results << Edge.new(from: from.id, to: to.id, relationship:)
      end

      def explicit_relationship(dependency)
        return "route" if dependency[:http_route]
        return "Pub/Sub" if dependency[:pubsub_publish] || dependency[:pubsub_subscribe]
        return "Kafka" if dependency[:kafka_publish] || dependency[:kafka_subscribe]

        nil
      end

      def find_service(name)
        system.config_nodes.values.find { |service| service.name == name }
      end

      def normalize_name(name)
        name.to_s.tr("_", "-")
      end

      def safe_id(type, name, occurrence)
        digest = Digest::SHA256.hexdigest([type, name, occurrence].join("\0"))[0, 16]
        "service_#{digest}"
      end

      def humanize(value)
        value.to_s.tr("_", " ").sub(/s\z/, "")
      end
    end

    class MermaidDiagram
      SHAPES = {
        application: ['["', '"]'],
        data: ['[("', '")]'],
        gateway: ['{"', '"}'],
        infrastructure: ['[["', '"]]'],
        messaging: ['{{"', '"}}'],
        observability: ['(["', '"])']
      }.freeze

      CLASS_DEFINITIONS = {
        application: "fill:#123b3b,stroke:#5eead4,color:#e6fffb",
        data: "fill:#172554,stroke:#60a5fa,color:#eff6ff",
        gateway: "fill:#4c1d95,stroke:#c4b5fd,color:#f5f3ff",
        infrastructure: "fill:#27272a,stroke:#a1a1aa,color:#fafafa",
        messaging: "fill:#713f12,stroke:#fbbf24,color:#fffbeb",
        observability: "fill:#3f1d2e,stroke:#f472b6,color:#fdf2f8"
      }.freeze

      attr_reader :topology

      def initialize(topology)
        @topology = topology
      end

      def source
        lines = ["flowchart LR"]
        topology.nodes.each do |node|
          opening, closing = SHAPES.fetch(node.category)
          lines << "    #{node.id}#{opening}#{escape(node.label)}#{closing}"
        end
        topology.edges.each do |edge|
          connector = edge.relationship ? "-->|#{escape(edge.relationship)}|" : "-->"
          lines << "    #{edge.from} #{connector} #{edge.to}"
        end
        topology.nodes.group_by(&:category).each do |category, nodes|
          lines << "    class #{nodes.map(&:id).join(",")} #{category}"
        end
        CLASS_DEFINITIONS.each do |category, style|
          lines << "    classDef #{category} #{style}"
        end
        lines.join("\n") << "\n"
      end

      private

      def escape(value)
        value.to_s
          .gsub("&", "&amp;")
          .gsub('"', "&quot;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub("|", "&#124;")
          .gsub(/[\r\n]+/, " ")
      end
    end
  end
end
