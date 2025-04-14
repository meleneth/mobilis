# frozen_string_literal: true

require "json"

module Mobilis
  class System
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :nodes

    def initialize
      @nodes = {}
    end

    def <<(node)
      raise ArgumentError, "Node must have an id" unless node.respond_to?(:id) && node.id

      @nodes[node.id] = node
    end

    def [](id)
      @nodes[id]
    end

    def each_node(&block)
      return enum_for(:each_node) unless block_given?

      @nodes.values.each(&block)
    end

    def resolve!
      @nodes.each_value do |node|
        node.resolve_references_using(@nodes) if node.respond_to?(:resolve_references_using)
      end
    end

    def to_h
      {
        name: "mobilis",
        nodes: @nodes.values.map(&:to_h)
      }
    end

    def to_json(*args)
      JSON.dump(to_h)
    end

    def node_count
      @nodes.count
    end

    def self.from_h(hash)
      sys = new
      raw_nodes = hash[:nodes] || []

      raw_nodes.each do |node_data|
        klass = Object.const_get(node_data[:type])
        node_data.delete(:type)
        data = node_data.transform_keys(&:to_sym)
        name = data.delete(:name)
        node = klass.new(name, **data)
        sys << node
      end

      sys.resolve!
      sys
    end

    def self.from_json(json)
      from_h(JSON.parse(json, symbolize_names: true))
    end

    def ppx_fields(dsl)
      dsl.instance_value "name", name
      nodes.sort_by(&:name).each do |node|
        dsl.child_object node.name, node
      end
    end
  end
end
