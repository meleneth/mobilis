# frozen_string_literal: true

module Mobilis
  module Model
    module SQLAlchemy
      # SQLAlchemy expressions are passed through as Python source, not interpreted.
      class Model
        attr_reader :name, :table, :columns

        def initialize(name, table: nil, columns: [])
          raise ArgumentError, "Invalid Python model name" unless name.match?(/\A[A-Z][A-Za-z0-9_]*\z/)

          @name = name
          @table = table || name.downcase
          @columns = columns
        end

        def column(name, sql_type, python_type:, primary_key: false, nullable: false, unique: false,
          default: nil, foreign_key: nil)
          raise ArgumentError, "Invalid column name" unless name.match?(/\A[a-z_][a-z0-9_]*\z/)
          raise ArgumentError, "Duplicate column #{name}" if columns.any? { |col| col[:name] == name }

          columns << {name: name, sql_type: sql_type, python_type: python_type,
                       primary_key: primary_key, nullable: nullable, unique: unique,
                       default: default, foreign_key: foreign_key}
          self
        end

        def to_h
          {type: self.class.name, name: name, table: table, columns: columns}
        end

        def self.from_h(hash)
          new(hash[:name], table: hash[:table], columns: hash[:columns])
        end
      end
    end
  end
end
