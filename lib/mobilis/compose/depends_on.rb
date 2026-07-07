# frozen_string_literal: true

module Mobilis
  module Compose
    class DependsOn
      attr_reader :data

      def initialize(base: nil)
        @data = Hash.new
        @base = base
      end

      def register(realized_node, force_skip_health_checks: false)
        condition = realized_node.has_healthcheck? ? "service_healthy" : "service_started"
        condition = "service_started" if force_skip_health_checks

        @data[realized_node.name.to_sym] = {
          condition: condition,
          restart: realized_node.dependant_services_require_restart? || nil
        }.compact
      end

      def as_json(*_args)
        output = Hash.new
        @base.data.each { |key, value| output[key] = value } if @base
        @data.each { |key, value| output[key] = value }
        output
      end

      def to_json(*_args)
        as_json.to_json
      end
    end
  end
end
