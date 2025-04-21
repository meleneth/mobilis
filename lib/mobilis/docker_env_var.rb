# frozen_string_literal: true

module Mobilis
  # resolved_name is the name that is actually fed to the docker container,
  # and is usually required to be a name that the container is looking for.
  # the specific name will ususally have the name of the instance in it, so that
  # you can use multiple containers of the same type but with different configs.
  class DockerEnvVar
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :resolved_name, :specific_name
    attr_accessor :value

    def initialize(resolved_name, specific_name, value)
      @resolved_name = normalize(resolved_name)
      @specific_name = normalize(specific_name)
      @value = value
    end

    def docker_repr
      "#{resolved_name}=${#{specific_name}}"
    end

    def env_repr
      "#{specific_name}=#{@value}"
    end

    def to_compose
      docker_repr
    end

    def as(name)
      DockerEnvVar.new(name, specific_name, value)
    end

    def ppx_fields(dsl)
      dsl.instance_value "resolved", resolved_name, styles: [:green]
      dsl.instance_value "specific", specific_name, styles: [:blue]
      dsl.instance_value "value", value, styles: [:yellow]
    end

    private

    def normalize(value)
      value.to_s.upcase.tr("-", "_")
    end
  end
end
