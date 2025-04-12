# frozen_string_literal: true

#
# Mobilis::PrettyPrint::PrettyPrintable
# Mixin to make any object printable with JobesWar + DSL.
# Defines `ppx_box` and `pp` so `puts obj.pp` Just Works.

module Mobilis
  module PrettyPrint
    module PrettyPrintable
      def pp
        JobesWar.draw do |diagram|
          DSL.render(self, diagram) do
            ruby_class # default to class box + fields
          end
        end.render
      end

      # Override this in subclasses to define the structure
      def ppx_fields(instance)
        # e.g. instance_value "UUID", uuid
        #      child_object "DB", primary_database
      end

      def ppx_box(parent)
        DSL.render(self, parent) do
          ruby_class
        end
      end
    end
  end
end
