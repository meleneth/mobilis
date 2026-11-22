# frozen_string_literal: true

module Mobilis
  module GeneratorCompatibility
    class UnsupportedInvocationError < KeyError; end

    class Registry
      def initialize
        # @type ivar @entries: Hash[Array[String], CapturedFileCreation]
        @entries = {}
      end

      def register(generator:, version:, arguments:, transformation:)
        key = invocation_key(generator, version, arguments)
        raise ArgumentError, "Compatibility invocation already registered: #{key.join(" ")}" if @entries.key?(key)

        @entries[key] = transformation
        self
      end

      def apply(generator:, version:, arguments:, workspace:)
        key = invocation_key(generator, version, arguments)
        transformation = @entries[key]
        raise UnsupportedInvocationError, "Unsupported generator invocation: #{key.join(" ")}" unless transformation

        transformation.apply(workspace)
      end

      private

      def invocation_key(generator, version, arguments)
        [String(generator), String(version), *Array(arguments).map(&:to_s)].freeze
      end
    end
  end
end
