# frozen_string_literal: true

module Mobilis
  # Holds the realized graph layer.  This extends the config only graph
  # to hold the actual details that will be written to disk later, for plugin extension
  class RealizedEnv
    extend Forwardable
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :system, :environment, :nodes

    def_delegators :@environment, :is_production?, :is_development?, :is_test?

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

    def node_by_name(name)
      @nodes.each do |possible|
        return possible if possible.name == name
      end
      raise "Could not find node for name #{name} on #{environment}"
    end

    def find_node_by_name(name)
      nodes.find { |no| no.name == name }
    end

    def ppx_fields(dsl)
      dsl.instance_value "environment", environment
      nodes.sort_by(&:name).each do |node|
        dsl.child_object node.name, node
      end
    end

    def required_plugins
      nodes
        .flat_map(&:required_plugins)
        .uniq
    end

    def each_node_of_type(klass)
      return enum_for(:each_node_of_type) unless block_given?

      nodes.each do |node|
        yield self, node if node.instance_of? klass
      end
    end

    private

    def build_all_nodes!
      system.each_node do |node|
        realized = build_realized_node(node)
        nodes << realized if realized
      end
      nodes.each do |node|
        node.after_all_nodes_realized
      end
    end

    def build_realized_node(node)
      case node
      when Mobilis::Node::PostgreSQL
        Mobilis::Realized::PostgreSQL.new(self, node, external_port_no: 15_432) # <-- for now, hardcoded or stubbed
      when Mobilis::Node::Rails
        Mobilis::Realized::Rails.new(self, node)
      else
        nil
      end
    end
  end
end
