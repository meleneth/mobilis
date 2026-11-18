# frozen_string_literal: true

module Mobilis
  module Node
    class Grafbase < Mobilis::Base::Node
      attr_reader :port

      def initialize(name, port: nil, **args)
        super(name, **args)
        if port && (!port.is_a?(Integer) || !(1..65_535).cover?(port))
          raise ArgumentError, "Invalid Grafbase port"
        end

        @port = port
      end

      def to_h
        port ? super.merge(port: port) : super
      end
    end
  end
end
