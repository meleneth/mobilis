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

        def each_model_of_type(klass)
          return enum_for(:each_model_of_type, klass) unless block_given?

          models.each do |model|
            yield model if model.is_a?(klass)
          end
        end
      end
    end
  end
end
