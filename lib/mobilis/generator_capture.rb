# frozen_string_literal: true

require "mobilis/generator_capture/definition"
require "mobilis/generator_capture/snapshot"
require "mobilis/generator_capture/runner"
require "mobilis/generator_capture/comparison"

module Mobilis
  module GeneratorCapture
    module_function

    def define(name, &block)
      definition = Definition.new(name)
      definition.instance_exec(&block)
      definition.validate!
    end
  end
end
