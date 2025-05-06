# frozen_string_literal: true

module Mobilis
  module Compose
    class Environment
      attr_reader :data

      def initialize(envfile: false, base: nil)
        @data = []
        @base = base
        @envfile = envfile
      end

      def add(env_var)
        @data << env_var
      end

      def as_json(*_args)
        merged = {}
        return @data.each { |item| item.env_repr } if @envfile

        @base&.data&.each { |item| merged[item.key] = item.value }
        @data.each { |item| merged[item.key] = item.value }
        merged.sort.map { |name, value| "#{name}=#{value}" }
      end

      def to_json(*_args)
        as_json.to_json
      end
    end
  end
end
