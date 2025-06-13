# frozen_string_literal: true

module Mobilis
  module DSL
    def self.generate(name, &block)
      system = Mobilis::System.new(name)
      ctx = DSLContext.new(system)
      ctx.instance_exec(&block)
      Manifest.new(system).materialize
    end

    class DSLContext
      attr_reader :system

      def initialize(system)
        @system = system
        @named = {}
      end

      def rails(name, primary_database:, api: false, &block)
        node = Mobilis::Node::Rails.new(name)
        node.primary_database = primary_database
        node.api_mode = api
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def postgres(name, &block)
        node = Mobilis::Node::PostgreSQL.new(name)
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def redis(name, &block)
        node = Mobilis::Node::Redis.new(name)
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def otel_collector(name, &block)
        node = Mobilis::Node::OtelCollector.new(name)
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def flask(name, &block)
        node = Mobilis::Node::Flask.new(name)
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def grafana(name, &block)
        node = Mobilis::Node::Grafana.new(name)
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def jaeger(name, &block)
        node = Mobilis::Node::Jaeger.new(name)
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def prometheus(name, &block)
        node = Mobilis::Node::Prometheus.new(name)
        system << node
        @named[name] = node
        block&.call(node)
        node
      end

      def connect(from:, to:, force_skip_health_checks: false)
        from_node = from.is_a?(String) ? @named.fetch(from) : from
        to_node   = to.is_a?(String)   ? @named.fetch(to)   : to
        from_node.has_extra_depends_on(to_node, force_skip_health_checks: force_skip_health_checks)
      end

      def named(name)
        @named.fetch(name)
      end
    end
  end
end
