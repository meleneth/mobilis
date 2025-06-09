# frozen_string_literal: true

module Mobilis
  module Model
    module GraphQL
      class Model
        attr_reader :name, :fields

        def initialize(name)
          @name = name
          @fields = []
        end
      end
    end
  end
end
