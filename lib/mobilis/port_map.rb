module Mobilis
  class PortMap
    attr_reader :internal_port_no, :external_port_no, :memo

    include Mobilis::PrettyPrint::DSL

    def initialize(external_port_no, internal_port_no, memo = "Unknown port mapping")
      @internal_port_no = internal_port_no
      @external_port_no = external_port_no
      @memo = memo
    end

    def as_key
      "#{external_port_no}:#{internal_port_no}"
    end

    def pretty_print(pp)
      obj = self
      ppx(pp) do
        row "external", obj.external_port_no.to_s,
            "internal", obj.internal_port_no.to_s,
            note: obj.memo
      end
      pp
    end
  end
end
