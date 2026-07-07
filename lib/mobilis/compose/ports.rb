# frozen_string_literal: true

module Mobilis
  module Compose
    class Ports
      attr_reader :data

      def initialize(base: nil)
        @data = []
        @base = base
      end

      def add(port)
        @data << port
      end

      def as_json(*_args)
        merged = Hash.new
        @base&.data&.each { |item| merged[item.key] = item.value }
        @data.each { |item| merged[item.key] = item.value }
        merged.sort.map { |name, value| "#{name}:#{value}" }
      end

      def to_json(*_args)
        as_json.to_json
      end
    end
  end
end
