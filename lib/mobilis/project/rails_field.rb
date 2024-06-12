# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'

module Mobilis
  class RailsField
    attr_reader :name
    attr_reader :type
    attr_reader :rails_model

    def initialize(name:, rails_model:, type:)
      @rails_model = rails_model
      @name = name
      @type = type
    end

    def line
      "rails g scaffold #{name} "
    end

    def for_line
      [@name, @type.name].join(":")
    end

    def to_h
      {name: @name, type: @type.name.to_sym}
    end

    def to_graphql
      if @type == Mobilis::RAILS_MODEL_TYPE_STRING
        return "#{@name}:String"
      end
      if @type == Mobilis::RAILS_MODEL_TYPE_INTEGER
        return "#{@name}:Int"
      end
      if @type == Mobilis::RAILS_MODEL_TYPE_REFERENCE
        model_name = @name.pluralize
        model_class = @name.camelcase
        return "#{model_name}:[#{model_class}]"
      end
      raise "Didn't know how to convert #{@name} of type #{@type.name} to a GraphQL field, but it was requested"
    end
  end
end
