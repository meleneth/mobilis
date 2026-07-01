# frozen_string_literal: true

module Mobilis
  module Node
    class Promtail < Mobilis::Base::Node
      include Mobilis::PrettyPrint::PrettyPrintable

      ref_attr :loki

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.child_object "loki", loki
      end
    end
  end
end
