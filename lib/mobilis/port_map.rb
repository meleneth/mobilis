module Mobilis
  class PortMap
    attr_reader :internal_port_no, :external_port_no, :memo

    include Mobilis::PrettyPrint::PrettyPrintable

    def initialize(external_port_no, internal_port_no, memo = "Unknown port mapping")
      @internal_port_no = internal_port_no
      @external_port_no = external_port_no
      @memo = memo
    end

    def as_key
      "#{external_port_no}:#{internal_port_no}"
    end

    def to_compose
      as_key
    end

    def name
      as_key
    end

    def ppx_fields(dsl)
      dsl.instance_value "external", external_port_no
      dsl.instance_value "internal", internal_port_no
      dsl.instance_value "memo", memo
    end
  end
end
