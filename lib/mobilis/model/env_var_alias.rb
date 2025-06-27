# frozen_string_literal: true

module Mobilis
  module Model
    class EnvVarAlias
      attr_reader :local_name, :service_name

      def initialize(local_name, service_name)
        @local_name = local_name
        @service_name = service_name
      end

      def to_h
        {
          type: self.class.name,
          local_name: local_name,
          service_name: service_name
        }
      end

      def self.from_h(hash)
        new(hash[:local_name], hash[:service_name])
      end

      def ppx_fields(dsl)
        dsl.simple_value "local_name", local_name
        dsl.simple_value "service_name", service_name
      end
    end
  end
end
