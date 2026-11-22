# frozen_string_literal: true

require "json"

module Mobilis
  module Browser
    class ServiceInspector
      Dependency = Data.define(:target, :kind, :source_id, :relationship)
      Service = Data.define(
        :id, :name, :type, :declaration, :editable_properties, :configuration,
        :outgoing, :incoming, :dependencies, :references
      )

      attr_reader :analysis, :topology

      def initialize(analysis, topology, property_schemas: SourceDocument::PROPERTY_SCHEMAS)
        @analysis = analysis
        @topology = topology
        @property_schemas = property_schemas
      end

      def services
        @services ||= topology.nodes.map { |topology_node| build_service(topology_node) }.freeze
      end

      private

      def build_service(topology_node)
        system = analysis.system or raise ArgumentError, "Cannot inspect a source document without a valid system"
        node = system.config_nodes.fetch(topology_node.service_id)
        declaration = analysis.declarations.find { |candidate| candidate.id == topology_node.source_id }
        outgoing = analysis.relationships.select { |relationship| relationship.from == node.name }
        incoming = analysis.relationships.select do |relationship|
          [relationship.to, relationship.properties[:candidate], relationship.properties[:shadow]]
            .compact.map { |name| normalize_name(name) }.include?(node.name)
        end

        # @type var editable_properties: Hash[Symbol, untyped]
        editable_properties = declaration ? @property_schemas.fetch(declaration.type) { Hash.new } : Hash.new

        Service.new(
          id: topology_node.id,
          name: node.name,
          type: topology_node.type,
          declaration:,
          editable_properties:,
          configuration: configuration(node),
          outgoing:,
          incoming:,
          dependencies: dependencies(node),
          references: references(node)
        )
      end

      def configuration(node)
        JSON.pretty_generate(node.to_h.transform_keys(&:to_s))
      end

      def dependencies(node)
        node.extra_depends_on.filter_map do |dependency|
          target = dependency[:target] || find_node(dependency[:name])
          next unless target

          relationship = analysis.relationships.find do |candidate|
            candidate.from == node.name && relationship_targets(candidate).include?(target.name)
          end
          Dependency.new(target: target.name, kind: :operational, source_id: relationship&.id, relationship: relationship&.kind)
        end
      end

      def references(node)
        singular = node.class.ref_attr_registry.filter_map do |slot|
          target = node.public_send(slot.name)
          Dependency.new(target: target.name, kind: slot.name, source_id: nil, relationship: :reference) if target.is_a?(Mobilis::Base::Node)
        end
        plural = node.class.ref_list_registry.flat_map do |slot|
          targets = node.public_send(slot.name)
          next [] unless targets.is_a?(Array)

          targets.filter_map do |target|
            Dependency.new(target: target.name, kind: slot.name, source_id: nil, relationship: :reference) if target.is_a?(Mobilis::Base::Node)
          end
        end
        singular + plural
      end

      def relationship_targets(relationship)
        [relationship.to, relationship.properties[:candidate], relationship.properties[:shadow]]
          .compact.map { |name| normalize_name(name) }
      end

      def find_node(name)
        system = analysis.system or raise ArgumentError, "Cannot inspect a source document without a valid system"
        system.config_nodes.values.find { |node| node.name == normalize_name(name) }
      end

      def normalize_name(name)
        name.to_s.tr("_", "-")
      end
    end
  end
end
