# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for SQL Databases
    class SQLite < Mobilis::Node::SQLDatabase
      include Mobilis::PrettyPrint::PrettyPrintable

      def ppx_fields(dsl)
        dsl.instance_value "name", name
      end
    end
  end
end
