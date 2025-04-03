module Mobilis
  class PortMap
    attr_reader :internal_port_no
    attr_reader :external_port_no
    attr_reader :memo

    def initialize(external_port_no, internal_port_no, memo="Unknown port mapping")
      @internal_port_no = internal_port_no
      @external_port_no = external_port_no
      @memo = memo
    end

    def as_key
      "#{external_port_no}:#{internal_port_no}"
    end
  end
end
