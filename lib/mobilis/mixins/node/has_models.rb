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

        def has_model_class?(klass)
          each_model_of_type(klass) do |model|
            return true
          end
        end

        def add_model(model)
          @models << model
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
