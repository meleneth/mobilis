# frozen_string_literal: true

module Mobilis
  module Model
    module Rails
      class Model
        attr_reader :name, :fields

        def self.from_h(hash)
          model = new(hash[:name])
          field_class = Mobilis::Model::Rails::Field

          expected = name
          actual = hash[:type] || hash["type"]
          raise ArgumentError, "Expected type #{expected.inspect}, got #{actual.inspect}" unless actual == expected

          (hash[:fields] || []).each do |field_hash|
            model.fields << field_class.from_h(field_hash)
          end

          model
        end

        def initialize(name)
          @name = name
          @fields = []
        end

        def field_args
          fields.map do |field|
            "#{field.name}:#{field.type}"
          end
        end

        def add_field(field_name, type, **options)
          @fields << Field.new(name: field_name, type: type, **options)
          self
        end

        def boolean(name, **options)
          add_field(name, "boolean", **options)
        end

        def datetime(name, **options)
          add_field(name, "datetime", **options)
        end

        def integer(name, **options)
          add_field(name, "integer", **options)
        end

        def string(name, **options)
          add_field(name, "string", **options)
        end

        def text(name, **options)
          add_field(name, "text", **options)
        end

        def references(name, **options)
          add_field(name, "references", **options)
        end

        def to_h
          {
            type: self.class.name,
            name: name,
            fields: fields.map(&:to_h)
          }
        end
      end
    end
  end
end
