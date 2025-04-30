# frozen_string_literal: true

require "json"

module Mobilis
  class System
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :config_nodes
    attr_reader :meta_project_name

    def initialize(meta_project_name)
      @config_nodes = {}
      @meta_project_name = meta_project_name
    end

    def <<(config_node)
      raise ArgumentError, "Node must have an id" unless config_node.respond_to?(:id) && config_node.id

      config_nodes[config_node.id] = config_node
    end

    def [](id)
      config_nodes[id]
    end

    def each_config_node(&block)
      return enum_for(:each_config_node) unless block_given?

      config_nodes.values.each(&block)
    end

    def resolve!
      config_nodes.each_value do |node|
        node.resolve_references_using(config_nodes) if node.respond_to?(:resolve_references_using)
      end
    end

    def to_h
      {
        name: "mobilis",
        meta_project_name: meta_project_name,
        nodes: config_nodes.values.map(&:to_h)
      }
    end

    def to_json(*args)
      JSON.dump(to_h)
    end

    def node_count
      config_nodes.count
    end

    def self.from_h(hash)
      sys = new(hash[:meta_project_name])
      raw_nodes = hash[:nodes] || []

      raw_nodes.each do |node_data|
        klass = Object.const_get(node_data[:type])
        node_data.delete(:type)
        data = node_data.transform_keys(&:to_sym)
        name = data.delete(:name)
        config_node = klass.new(name, **data)
        sys << config_node
      end

      sys.resolve!
      sys
    end

    def self.from_json(json)
      from_h(JSON.parse(json, symbolize_names: true))
    end

    def ppx_fields(dsl)
      config_nodes.sort_by(&:name).each do |config_node|
        dsl.child_object config_node.name, node
      end
    end
  end
end
