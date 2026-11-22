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

    # One sequence is shared by the three realized environments of a manifest.
    # A standalone RealizedEnv gets its own sequence for deterministic inspection.
    class PortAllocator
      def initialize(starting_port, reservation_count: 1)
        @next_port = starting_port
        @reservation_count = reservation_count
        # @type ivar @reserved_ports: Hash[Integer, bool]
        @reserved_ports = {}
        # @type ivar @preferred_sequences: Hash[String, Array[Integer]]
        @preferred_sequences = {}
      end

      def reserve(preferred_port: nil, allocation_key: nil)
        return reserve_preferred(preferred_port, allocation_key) if preferred_port

        @next_port += 10 while @reserved_ports.key?(@next_port)
        validate_port!(@next_port)

        port = @next_port
        @reserved_ports[port] = true
        @next_port += 10
        port
      end

      private

      def reserve_preferred(preferred_port, allocation_key)
        raise ArgumentError, "Preferred host ports require an allocation key" unless allocation_key

        sequence = @preferred_sequences[allocation_key] ||= begin
          ports = @reservation_count.times.map { |index| preferred_port + (index * 10) }
          ports.each do |port|
            validate_port!(port)
            raise ArgumentError, "Generated host port #{port} is already reserved" if @reserved_ports.key?(port)
          end
          ports.each { |port| @reserved_ports[port] = true }
          ports
        end
        raise ArgumentError, "Preferred host-port sequence is exhausted" if sequence.empty?

        sequence.shift
      end

      def validate_port!(port)
        raise ArgumentError, "Generated host ports exceed 65535" if port > 65_535
        raise ArgumentError, "Generated host ports must be positive" if port < 1
      end
    end

    def_delegators :@environment, :is_production?, :is_development?, :is_test?
    def_delegators :@system, :meta_project_name

    def initialize(system, environment, port_allocator: nil)
      @system = system
      @environment = environment
      @realized_nodes = []
      @port_allocator = port_allocator || PortAllocator.new(system.starting_port)

      build_all_nodes!
    end

    def reserve_external_port(preferred_port: nil, allocation_key: nil)
      @port_allocator.reserve(preferred_port: preferred_port, allocation_key: allocation_key)
    end

    def to_s
      environment.to_s
    end

    def <<(realized_node)
      realized_nodes << realized_node
    end

    def realized_node_for_config_node(system_node)
      realized_nodes.each do |possible|
        return possible if possible.config_node.name == system_node.name
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
        yield self, node if node.is_a? klass
      end
    end

    def each_node
      return enum_for(:each_node) unless block_given?

      realized_nodes.each do |node|
        yield node
      end
    end

    # rubocop:disable all
    def all_envfile_vars
      return enum_for(:all_envfile_vars) unless block_given?
      each_node do |realized_node|
        realized_node.env_vars_for_env_file do |emit_var|
          yield emit_var
        end
      end
    end
    # rubocop:enable all

    private

    def build_all_nodes!
      system.each_config_node do |config_node|
        realized = build_realized_node(config_node)
        realized_nodes << realized if realized
        raise "No RealizedNode for #{config_node.name}" unless realized
      end
      realized_nodes.each do |realized_node|
        realized_node.after_all_nodes_realized
        realized_node.extra_depends_on.each do |extra_dep|
          target = extra_dep[:target]
          next unless target.is_a?(Mobilis::Base::Node)

          realized_dependency = realized_node_for_config_node(target)
          raise Mobilis::NoSuchNode.new("Could not find node for name #{target.name} on #{environment}") unless realized_dependency

          extra_dep[:target] = realized_dependency
        end
      end
      realized_nodes.each(&:populate_compose_depends_on)
    end

    def build_realized_node(config_node)
      case config_node
      when Mobilis::Node::FastAPI then Mobilis::Realized::FastAPI.new(self, config_node)
      when Mobilis::Node::Airflow then Mobilis::Realized::Airflow.new(self, config_node)
      when Mobilis::Node::GoHTTP then Mobilis::Realized::GoHTTP.new(self, config_node)
      when Mobilis::Node::Envoy then Mobilis::Realized::Envoy.new(self, config_node)
      when Mobilis::Node::Grafbase then Mobilis::Realized::Grafbase.new(self, config_node)
      when Mobilis::Node::Localstack then Mobilis::Realized::Localstack.new(self, config_node)
      when Mobilis::Node::PostgreSQL then Mobilis::Realized::PostgreSQL.new(self, config_node)
      when Mobilis::Node::Cassandra then Mobilis::Realized::Cassandra.new(self, config_node)
      when Mobilis::Node::Pgadmin then Mobilis::Realized::Pgadmin.new(self, config_node)
      when Mobilis::Node::MySQL then Mobilis::Realized::MySQL.new(self, config_node)
      when Mobilis::Node::OtelCollector then Mobilis::Realized::OtelCollector.new(self, config_node)
      when Mobilis::Node::Jaeger then Mobilis::Realized::Jaeger.new(self, config_node)
      when Mobilis::Node::Prometheus then Mobilis::Realized::Prometheus.new(self, config_node)
      when Mobilis::Node::Grafana then Mobilis::Realized::Grafana.new(self, config_node)
      when Mobilis::Node::Loki then Mobilis::Realized::Loki.new(self, config_node)
      when Mobilis::Node::Alloy then Mobilis::Realized::Alloy.new(self, config_node)
      when Mobilis::Node::Flask then Mobilis::Realized::Flask.new(self, config_node)
      when Mobilis::Node::Rack then Mobilis::Realized::Rack.new(self, config_node)
      when Mobilis::Node::Rails then Mobilis::Realized::Rails.new(self, config_node)
      when Mobilis::Node::Redis then Mobilis::Realized::Redis.new(self, config_node)
      when Mobilis::Node::S3Storage then Mobilis::Realized::S3Storage.new(self, config_node)
      when Mobilis::Node::GoAws then Mobilis::Realized::GoAws.new(self, config_node)
      when Mobilis::Node::GooglePubSub then Mobilis::Realized::GooglePubSub.new(self, config_node)
      when Mobilis::Node::Kafka then Mobilis::Realized::Kafka.new(self, config_node)
      end
    end
  end
end
