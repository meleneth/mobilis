# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for SQL Databases
    class MySQL < Mobilis::Node::SQLDatabase
      def ppx_fields(dsl)
        dsl.instance_value "name", name
      end
    end
  end
end
