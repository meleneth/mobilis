# frozen_string_literal: true

module Mobilis
  class RailsModelType
    attr_reader :name
    attr_reader :description
    def initialize(name:, description:)
      @name = name
      @description = description
    end
  end
  RAILS_MODEL_TYPES=[
    RAILS_MODEL_TYPE_REFERENCE=RailsModelType.new(name: :references, description: "a foreign key to another table.  This is where the \"relational\" in \"relational database\" comes from"),
    RailsModelType.new(name: :primary_key, description: "this data type is a kind of placeholder that Rails translates as a unique key to identify each row in your table"),
    RAILS_MODEL_TYPE_STRING=RailsModelType.new(name: :string, description: "used for short text fields, think \"name\" or \"title\" attributes, and has to be less than 255 characters"),
    RailsModelType.new(name: :text, description: "used for longer text fields, think \"comment\" or \"review\" attributes, and has a character limit of approximately 30,000 characters"),
    RailsModelType.new(name: :integer, description: "this type is used specifically for whole numbers ONLY, and can store numbers up to 2.1 billion"),
    RailsModelType.new(name: :bigint, description: "similar to :integer, with the difference being that it can store whole numbers up to approximately 20 digits long"),
    RailsModelType.new(name: :float, description: "used for decimal numbers with fixed precision"),
    RailsModelType.new(name: :decimal, description: "also used for decimal numbers, but use this type if you need to make specific calculations (precision is NOT fixed)"),
    RailsModelType.new(name: :datetime, description: "this data type is also known as :timestamp in Rails and they mean the same thing, used to store the date and the time"),
    RailsModelType.new(name: :time, description: "used to store a time ONLY (hours, minutes, seconds)"),
    RailsModelType.new(name: :date, description: "used to store a date ONLY (year, month, day)"),
    RailsModelType.new(name: :binary, description: "this type is used for storing data like images, movies, or audio files in their original raw format"),
    RailsModelType.new(name: :boolean, description: "used for true/false values, think of things with two states (\"not finished\" and \"complete\", or \"on\" and \"off\")"),
  ]

  NON_REFERENCE_MODEL_TYPES = RAILS_MODEL_TYPES - [RAILS_MODEL_TYPE_REFERENCE]
end
