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
        merged = Hash.new
        vars_for_compose do |item|
          merged[item.key] = item.compose_value
        end
        merged.sort.map { |name, value| "#{name}=#{value}" }
      end

      def to_json(*_args)
        as_json.to_json
      end

      def envfile_vars
        return enum_for(:envfile_vars) unless block_given?

        @base&.data&.each { |item| yield item unless item.envfile_name.nil? }
        @data.each { |item| yield item unless item.envfile_name.nil? }
      end

      def vars_for_compose
        return enum_for(:vars_for_compose) unless block_given?

        @base&.data&.each { |item| yield item unless item.do_not_resolve }
        @data.each { |item| yield item unless item.do_not_resolve }
      end
    end
  end
end
