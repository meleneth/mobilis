# frozen_string_literal: true

module Mobilis
  module Compose
    class Volume
      attr_reader :data

      def initialize(base: nil)
        @data = Hash.new
        @base = base
      end

      def add(local_path, container_path)
        @data[local_path] = container_path
      end

      def as_json(*_args)
        merged = Hash.new
        @data.each do |key, value|
          merged[key] = value
        end
        merged.sort.map { |name, value| "#{name}:#{value}" }
      end

      def to_json(*_args)
        as_json.to_json
      end
    end
  end
end
