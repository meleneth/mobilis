# frozen_string_literal: true

module Mobilis
  module Node
    class Grafbase < Mobilis::Base::Node
      attr_reader :port

      def initialize(name, port: 5000, **args)
        super(name, **args)
        raise ArgumentError, "Invalid Grafbase port" unless port.is_a?(Integer) && (1..65535).cover?(port)

        @port = port
      end

      def to_h
        super.merge(port: port)
      end
    end
  end
end
