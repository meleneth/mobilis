# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add command override support to RealizedNode.
      module HasCommand
        def command_override
          return compose[:command] if compose.has_key? :command

          false
        end

        def set_command(command)
          compose[:command] = [command]
        end
      end
    end
  end
end
