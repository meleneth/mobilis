# frozen_string_literal: true

module Mobilis
  module Mixins
    module Node
      # Mixin to add script support to Node
      module HasScripts
        def add_script(filename, contents)
          models << Mobilis::Model::Script.new(filename, contents)
        end

        def write_file(path, contents)
          models << Mobilis::Model::File.new(path, contents)
        end
      end
    end
  end
end
