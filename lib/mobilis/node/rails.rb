# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for Ruby on Rails
    class Rails < Mobilis::Node::Ruby
      include Mobilis::PrettyPrint::PrettyPrintable
      ref_attr :primary_database

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.child_object "primary_database", primary_database
      end
    end
  end
end
