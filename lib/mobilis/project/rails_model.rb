# frozen_string_literal: true

module Mobilis
  class RailsModel
    attr_accessor :name
    attr_accessor :fields
    attr_accessor :indexes
    attr_accessor :rails_project
    attr_reader :graphql_fields

    def initialize(name, rails_project)
      @rails_project = rails_project
      @name = name
      @fields = []
      @indexes = []
    end

    def line
      my_fields = @fields.map { |f| f.for_line }
      "./bin/rails g scaffold #{name} #{my_fields.join(' ')}"
    end

    def add_field(name:, type:)
      new_field = RailsField.new(name: name, rails_model: self, type: type)
      @fields << new_field
      new_field
    end

    def add_references(model)
      add_field(name: model.name.downcase, type: Mobilis::RAILS_MODEL_TYPE_REFERENCE)
    end

    def add_index(*index_field_names)
      @indexes << index_field_names
    end

    def set_graphql_fields(*index_field_names)
      @graphql_fields = index_field_names
    end

    def to_h
      my_fields = @fields.map(&:to_h)
      returned_h = {
        name: name,
        fields: my_fields,
        indexes: indexes,
      }
      returned_h[:graphql_fields] = @graphql_fields if @rails_project.graphql_enabled?
      returned_h
    end
  end
end
