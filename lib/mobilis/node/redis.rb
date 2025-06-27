# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for SQL Databases
    class Redis < Mobilis::Base::Node
      include Mobilis::PrettyPrint::PrettyPrintable

      def ppx_fields(dsl)
        dsl.instance_value "name", name
      end
    end
  end
end
