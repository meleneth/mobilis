# frozen_string_literal: true

module Mobilis
  # Holds the realized graph layer.  This extends the config only graph
  # to hold the actual details that will be written to disk later, for plugin extension
  class NoSuchNode < StandardError
  end

  class RealizedEnv
    extend Forwardable
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :system, :environment, :realized_nodes

    @@next_port_no = 11_000
    @@port_spacing = 10

    def_delegators :@environment, :is_production?, :is_development?, :is_test?

    def initialize(system, environment)
      @system = system
      @environment = environment
      @realized_nodes = []

      build_all_nodes!
    end

    def to_s
      environment.to_s
    end

    def <<(realized_node)
      realized_nodes << realized_node
    end

    def realized_node_for_config_node(system_node)
      realized_nodes.each do |possible|
        return possible if possible.config_node == system_node
      end
      nil
    end

    def realized_node_by_name(name)
      realized_nodes.each do |possible|
        return possible if possible.name == name
      end
      raise Mobilis::NoSuchNode.new("Could not find node for name #{name} on #{environment}")
    end

    def find_realized_node_by_name(name)
      realized_nodes.find { |no| no.name == name }
    end

    def ppx_fields(dsl)
      dsl.instance_value "environment", environment
      realized_nodes.sort_by(&:name).each do |node|
        dsl.child_object node.name, node
      end
    end

    def required_plugins
      realized_nodes
        .flat_map(&:required_plugins)
        .uniq
    end

    def each_node_of_type(klass)
      return enum_for(:each_node_of_type) unless block_given?

      realized_nodes.each do |node|
        yield self, node if node.instance_of? klass
      end
    end

    def each_node(&block)
      return enum_for(:each_node) unless block_given?

      realized_nodes.each(&block)
    end

    private

    def build_all_nodes!
      system.each_config_node do |config_node|
        realized = build_realized_node(config_node)
        realized_nodes << realized if realized
      end
      realized_nodes.each do |realized_node|
        realized_node.after_all_nodes_realized
      end
    end

    def build_realized_node(config_node)
      case config_node
      when Mobilis::Node::PostgreSQL
        Mobilis::Realized::PostgreSQL.new(self, config_node) # <-- for now, hardcoded or stubbed
      when Mobilis::Node::Rails
        Mobilis::Realized::Rails.new(self, config_node)
      else
        nil
      end
    end
  end
end
