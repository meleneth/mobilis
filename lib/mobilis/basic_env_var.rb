# frozen_string_literal: true

module Mobilis
  class BasicEnvVar
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :specific_name
    attr_accessor :value

    def initialize(specific_name, value)
      @specific_name = normalize(specific_name)
      @value = value
    end

    def docker_repr
      "#{specific_name}=#{value}"
    end

    def env_repr
      docker_repr
    end

    def resolved_name
      ""
    end

    def to_compose
      docker_repr
    end

    def ppx_fields(dsl)
      dsl.instance_value "specific_name", specific_name, styles: [:green]
      dsl.instance_value "value", value, styles: [:yellow]
    end

    private

    def normalize(value)
      value.to_s.upcase.tr("-", "_")
    end
  end
end
