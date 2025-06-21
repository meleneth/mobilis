# frozen_string_literal: true

module Mobilis
  module Model
    module Rails
      class GraphQL
        def self.from_h(hash)
          new
        end

        def to_h
          {
            type: self.class.name
          }
        end
      end
    end
  end
end
