# frozen_string_literal: true

module Mobilis
  class ExecutionEnvironment
    include Mobilis::PrettyPrint::DSL
    attr_reader :value

    def initialize(value)
      @value = value.downcase.to_sym
    end

    def is_dev?
      @value == :development
    end

    def is_test?
      @value == :test
    end

    def is_production?
      @value == :production
    end

    def is_staging?
      @value == :staging
    end

    def to_s
      @value.to_s
    end

    def pretty_print(pp)
      ppx(pp) do
        heading object.class.name
        line "env_name", object.to_s
      end
      pp
    end
  end
end
