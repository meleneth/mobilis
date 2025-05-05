# frozen_string_literal: true

module Mobilis
  module Compose
    class DependsOn
      attr_reader :data

      def initialize(base: nil)
        @data = {}
        @base = base
      end

      def register(name, value)
        @data[name] = value
      end

      def as_json(*_args)
        output = {}
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
