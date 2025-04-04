# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for SQL Databases
    class PostgreSQL < Mobilis::Node::SQLDatabase
      include Mobilis::PrettyPrint::DSL

      def pretty_print(pp)
        ppx(pp) do
          heading object.class.name
          line "name", object.name
        end
        pp
      end

    end
  end
end
