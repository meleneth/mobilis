# frozen_string_literal: true

require "mobilis/generator_capture/definition"
require "mobilis/generator_capture/snapshot"
require "mobilis/generator_capture/runner"
require "mobilis/generator_capture/comparison"

module Mobilis
  module GeneratorCapture
    module_function

    def define(name, &block)
      Definition.new(name).tap { |definition| definition.instance_eval(&block) }.validate!
    end
  end
end
