# frozen_string_literal: true

module Mobilis
  module Model
    module Rails
      class Field
        attr_reader :name, :type

        def self.from_h(hash)
          new(name: hash[:name], type: hash[:type])
        end

        def initialize(name:, type:)
          @name = name
          @type = type
        end

        def to_h
          { name: @name, type: @type }
        end
      end
    end
  end
end
