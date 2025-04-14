# frozen_string_literal: true

module Mobilis
  class DockerEnvVar
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :resolved_name, :specific_name
    attr_accessor :value

    def initialize(resolved_name, specific_name, value)
      @resolved_name = resolved_name
      @specific_name = specific_name
      @value = value
    end

    def docker_repr
      "#{resolved_name}: ${#{specific_name}}"
    end

    def env_repr
      "#{specific_name}=#{@value}"
    end

    def as(name)
      DockerEnvVar.new(name, specific_name, value)
    end

    def ppx_fields(dsl)
      dsl.instance_value "resolved", resolved_name, styles: [:green]
      dsl.instance_value "specific", specific_name, styles: [:blue]
      dsl.instance_value "value", value, styles: [:yellow]
    end
  end
end
