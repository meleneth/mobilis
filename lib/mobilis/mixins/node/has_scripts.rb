# frozen_string_literal: true

module Mobilis
  module Mixins
    module Node
      # Mixin to add script support to Node
      module HasScripts
        def add_script(filename, contents)
          models << Mobilis::Model::Script.new(filename, contents)
        end
      end
    end
  end
end
