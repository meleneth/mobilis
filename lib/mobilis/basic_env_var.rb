# frozen_string_literal: true

module Mobilis
  class BasicEnvVar
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :resolved_name
    attr_accessor :value

    def initialize(resolved_name, value)
      @resolved_name = normalize(resolved_name)
      @value = value
    end

    def docker_repr
      "#{resolved_name}=#{value}"
    end

    def ppx_fields(dsl)
      dsl.instance_value "resolved", resolved_name, styles: [:green]
      dsl.instance_value "value", value, styles: [:yellow]
    end

    private

    def normalize(value)
      value.to_s.upcase.tr("-", "_")
    end
  end
end
