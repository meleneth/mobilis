# frozen_string_literal: true

# Mobilis::AutoVivify
# ---
# A smart Hash that auto-vivifies missing keys.
#
# Behavior:
# - If you `<<` to a missing key, it becomes an Array automatically.
# - If you `[]`-assign to a missing key, it becomes a Hash automatically.
# - Raises a TypeError if you try to mix incompatible modes (e.g., treat an Array as a Hash).
#
# This allows deeply dynamic tree building while preserving clean serialization.
# Used in Mobilis to support clean, overrideable, expandable config trees (e.g., Compose fragments).
#
# Note:
# - Auto-vivification is active at runtime.
# - Emitted JSON/YAML is pure Hashes and Arrays (no serialization artifacts).
#
module Mobilis
  class AutoVivify < Hash
    def initialize
      super do |hash, key|
        hash[key] = AutoValue.new(key)
      end

      def to_h
        result = {}
        each do |k, v|
          result[k] =
            case v
            when AutoValue
              v.unwrap
            else
              v
            end
        end
        result
      end
    end

    class AutoValue
      def initialize(key)
        @key = key
        @backing = nil
      end

      def <<(value)
        ensure_array!
        @backing << value
      end

      def unwrap
        case @backing
        when Hash
          @backing.transform_values do |v|
            v.respond_to?(:unwrap) ? v.unwrap : v
          end
        when Array
          @backing.map do |v|
            v.respond_to?(:unwrap) ? v.unwrap : v
          end
        else
          @backing
        end
      end

      def []=(k, v)
        ensure_hash!
        @backing[k] = v
      end

      def [](k)
        ensure_hash!
        @backing[k]
      end

      def to_h
        case @backing
        when Hash
          @backing.transform_values do |v|
            v.respond_to?(:to_h) ? v.to_h : v
          end
        when Array
          {}
        else
          {}
        end
      end

      def to_a
        case @backing
        when Array
          @backing.map { |v| v.respond_to?(:to_h) ? v.to_h : v }
        when Hash
          []
        else
          []
        end
      end

      def to_json(*args)
        case @backing
        when Hash
          to_h.to_json(*args)
        when Array
          to_a.to_json(*args)
        else
          {}.to_json(*args)
        end
      end

      def as_json(*args)
        case @backing
        when Hash
          to_h.as_json(*args)
        when Array
          to_a.as_json(*args)
        else
          {}
        end
      end

      def inspect
        case @backing
        when Hash, Array
          "#<AutoValue #{@backing.inspect}>"
        else
          "#<AutoValue nil>"
        end
      end

      private

      def ensure_array!
        return if @backing.is_a?(Array)
        raise TypeError, "Key #{@key.inspect} is already used as a Hash" if @backing

        @backing = []
      end

      def ensure_hash!
        return if @backing.is_a?(Hash)
        raise TypeError, "Key #{@key.inspect} is already used as an Array" if @backing

        @backing = {}
      end
    end

    def to_h
      result = {}
      each do |k, v|
        result[k] = v.respond_to?(:to_h) ? v.to_h : v
      end
      result
    end

    def inspect
      "#<Mobilis::AutoVivify #{super}>"
    end
  end
end
