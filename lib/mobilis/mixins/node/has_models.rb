# frozen_string_literal: true

module Mobilis
  module Mixins
    module Node
      module HasModels
        def models
          return @models if defined?(@models)

          @models = []
          @models
        end
      end
    end
  end
end
