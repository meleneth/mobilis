# frozen_string_literal: true

module Mobilis
  module Node
    class Envoy < Mobilis::Base::Node
      attr_reader :port, :verification_port

      def initialize(name, port: 8080, verification_port: nil, **args)
        super(name, **args)
        raise ArgumentError, "Invalid HTTP port" unless port.is_a?(Integer) && (1..65535).cover?(port)
        raise ArgumentError, "Invalid service name" unless self.name.match?(/\A[a-z][a-z0-9-]*\z/)

        if verification_port && (!verification_port.is_a?(Integer) || !(1..65535).cover?(verification_port) || verification_port == port || [9901, 9902].include?(verification_port))
          raise ArgumentError, "Invalid verification port"
        end
        @port = port
        @verification_port = verification_port
      end

      def to_h
        super.merge(port: port, verification_port: verification_port)
      end
    end
  end
end
