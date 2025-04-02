# frozen_string_literal: true

module Mobilis
  class DockerEnvVar
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
  end
end
