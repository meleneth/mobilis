# frozen_string_literal: true

module Mobilis
  module Node
    class Alloy < Mobilis::Base::Node
      include Mobilis::PrettyPrint::PrettyPrintable

      ref_attr :loki

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.child_object "loki", loki
      end
    end
  end
end
