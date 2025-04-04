# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for Ruby on Rails
    class Rails < Mobilis::Node::Ruby
      include Mobilis::PrettyPrint::DSL
      ref_attr :primary_database

      def pretty_print(pp)
        ppx(pp) do
          heading object.class.name
          line "name", object.name
          line "primary_database", object.primary_database&.name
          line "plugins", object.plugins.map(&:class).join(", ")
        end
        pp
      end
    end
  end
end
