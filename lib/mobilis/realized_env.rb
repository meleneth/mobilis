# frozen_string_literal: true

module Mobilis
  class RealizedEnv
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

    private

    def build_all_nodes!
      system.nodes.each do |node|
        realized = build_realized_node(node)
        nodes << realized if realized
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
  end
end
