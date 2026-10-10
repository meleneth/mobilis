# frozen_string_literal: true

require "json"

module Mobilis
  class System
    include Mobilis::PrettyPrint::PrettyPrintable

    attr_reader :config_nodes
    attr_reader :meta_project_name
    attr_accessor :kubernetes_deployment

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
      return enum_for(:each_config_node) unless block

      config_nodes.values.each { |config_node| block.call(config_node) }
    end

    def resolve!
      config_nodes.each_value do |node|
        node.resolve_references_using(config_nodes) if node.respond_to?(:resolve_references_using)
        node.extra_depends_on.map! do |dependency|
          dependency = {name: dependency} if dependency.is_a?(String)
          target_name = dependency[:name]
          if target_name
            target = config_nodes.values.find { |n| n.name == target_name }
            raise ArgumentError, "Unknown dependency #{target_name}" unless target

            dependency = dependency.dup
            dependency.delete(:name)
            dependency[:target] = target
          end
          dependency
        end
      end
    end

    def to_h
      result = {
        name: "mobilis",
        meta_project_name: meta_project_name,
        nodes: config_nodes.values.map(&:to_h)
      }
      result[:deploy_kubernetes] = kubernetes_deployment.to_h if kubernetes_deployment
      result
    end

    def to_json(*args)
      JSON.dump(to_h)
    end

    def node_count
      config_nodes.count
    end

    def self.from_h(hash)
      sys = new(hash[:meta_project_name])
      if hash[:deploy_kubernetes]
        sys.kubernetes_deployment = Mobilis::Kubernetes::Declaration.from_h(hash[:deploy_kubernetes])
      end
      raw_nodes = Array(hash[:nodes])

      raw_nodes.each do |node_data|
        # @type var node_data: Hash[Symbol, untyped]
        node_data = JSON.parse(node_data.to_json, symbolize_names: true)
        klass = Object.const_get(node_data[:type])
        models = node_data.delete(:models) || []

        node_data.delete(:type)
        name = node_data.delete(:name)
        config_node = klass.new(name, **node_data)

        models.each do |model|
          model_klass = Object.const_get(model[:type])
          model = model_klass.from_h(model)
          config_node.models << model
        end

        sys << config_node
      end

      sys.resolve!
      sys
    end

    def self.from_json(json)
      from_h(JSON.parse(json, symbolize_names: true))
    end

    def ppx_fields(dsl)
      config_nodes.values.sort_by(&:name).each do |config_node|
        dsl.child_object config_node.name, config_node
      end
    end
  end
end
