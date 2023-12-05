# frozen_string_literal: true

module Mobilis
  class RailsField
    attr_accessor :name
    attr_accessor :rails_model

    def initialize(name:, rails_model:, type:)
      @rails_model = rails_model
      @name = name
      @type = type
    end

    def line
      "rails g scaffold #{name} "
    end

    def for_line
      [@name, @type].join(":")
    end

    def to_json
      {name: @name, type: @type.name.to_sym}
    end
  end
end