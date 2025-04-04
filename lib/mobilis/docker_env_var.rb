# frozen_string_literal: true

module Mobilis
  class DockerEnvVar
    include Mobilis::PrettyPrint::DSL
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

    def pretty_print(pp)
      ppx(pp) do
        row pastel.green(object.resolved_name), pastel.yellow(object.value), note: object.specific_name
      end
    end
  end
end
