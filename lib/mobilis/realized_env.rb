# frozen_string_literal: true

# Represents the concrete, environment-specific transformation of a Mobilis::System.
# RealizedEnv is a structural container. It holds RealizedNode objects,
# but does not define or introspect their internals.
module Mobilis
  class RealizedEnv
    attr_reader :system, :nodes, :environment

    def initialize(system, environment)
      @system = system
      @nodes = []
      @environment = environment
    end

    # Adds a fully-formed RealizedNode to the environment
    #
    # @param node [Mobilis::Base::RealizedNode]
    def <<(node)
      nodes << node
    end
  end
end
