# frozen_string_literal: true

module Mobilis
  # Holds the realized graph layer.  This extends the config only graph
  # to hold the actual details that will be written to disk later, for plugin extension
  class RealizedEnv
    include Mobilis::PrettyPrint::DSL
    attr_reader :system, :environment, :nodes

    def initialize(system, environment)
      @system = system
      @environment = environment
      @nodes = []

      build_all_nodes!
    end

    def to_s
      environment.to_s
    end

    def <<(node)
      nodes << node
    end

    def node_for(system_node)
      @nodes.each do |possible|
        return possible if possible.node == system_node
      end
      nil
    end

    private

    def build_all_nodes!
      system.nodes.each do |node|
        pp node
        realized = build_realized_node(node)
        nodes << realized if realized
      end
      nodes.each do |node|
        node.after_all_nodes_realized(self)
      end
    end

    def build_realized_node(node)
      case node
      when Mobilis::Node::PostgreSQL
        RealizedNode::PostgreSQL.new(self, node, external_port_no: 15_432) # <-- for now, hardcoded or stubbed
      when Mobilis::Node::Rails
        RealizedNode::Rails.new(self, node)
      else
        nil
      end
    end

    def pretty_print(pp)
      ppx(pp) do
        heading object.class.name
        line "environment", object.execution_environment.to_s
        section "realized_nodes", object.nodes.sort_by(&:name) do |node|
          line node.name, node.class.name
        end
      end
      pp
    end
  end
end
