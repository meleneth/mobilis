# frozen_string_literal: true

module Mobilis
  module Model
    module Rails
      class Model
        attr_reader :name, :fields, :filterable_fields
        attr_accessor :api_exposed, :generate_model

        def self.from_h(hash)
          model = new(hash[:name])
          field_class = Mobilis::Model::Rails::Field

          expected = name
          actual = hash[:type] || hash["type"]
          raise ArgumentError, "Expected type #{expected.inspect}, got #{actual.inspect}" unless actual == expected

          (hash[:fields] || []).each do |field_hash|
            model.fields << field_class.from_h(field_hash)
          end
          model.api_exposed = hash[:api_exposed] || hash["api_exposed"]
          model.generate_model = hash.fetch(:generate_model, hash.fetch("generate_model", true))
          fields = hash[:filterable_fields] || hash["filterable_fields"] || []
          model.filterable(*fields) unless fields.empty?

          model
        end

        def initialize(name)
          @name = name
          @fields = []
          @filterable_fields = []
          @api_exposed = false
          @generate_model = true
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

        def expose_api!
          @api_exposed = true
          self
        end

        def existing!
          @generate_model = false
          self
        end

        def generate_model?
          !!generate_model
        end

        def filterable(*fields)
          @filterable_fields.concat(fields.map(&:to_s))
          expose_api!
        end

        def api_exposed?
          !!api_exposed
        end

        def to_h
          h = {
            type: self.class.name,
            name: name,
            fields: fields.map(&:to_h)
          }
          h[:api_exposed] = true if api_exposed?
          h[:generate_model] = false unless generate_model?
          h[:filterable_fields] = filterable_fields if filterable_fields.any?
          h
        end
      end
    end
  end
end
