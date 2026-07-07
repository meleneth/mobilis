# frozen_string_literal: true

# Mobilis::AutoVivify
# ---
# A smart Hash that auto-vivifies missing keys into structured data.
# - `[]` and `[]=` auto-initialize nested keys as AutoNode
# - `<<` initializes as an Array and appends
# - `[]=` initializes as a Hash and assigns
# - Clean to_h / to_a support
# - Raises TypeError if hash/array usage is mixed
#
# Used for override trees and config fragments.

module Mobilis
  class AutoVivify < Hash
    def initialize
      super { |h, k| h[k] = AutoNode.new(k) }
    end

    def clean_shrunk
      previous = nil
      current = deep_compact(JSON.parse(to_serial.to_json))

      until JSON.dump(current) == previous
        previous = JSON.dump(current)
        current = deep_compact(current)
      end
      JSON.parse(JSON.dump(current), symbolize_names: true)
    end

    def deep_compact(data)
      case data
      when Hash
        data.each_with_object({}) do |(k, v), h|
          compacted = deep_compact(v)
          h[k] = compacted unless compacted.nil? || compacted == {} || compacted == []
        end
      when Array
        compacted = data.map { |v| deep_compact(v) }.reject { |v| v.nil? || v == {} || v == [] }
        compacted unless compacted.empty?
      else
        data
      end
    end

    def to_h
      each_with_object({}) do |(k, v), result|
        result[k] = v.respond_to?(:to_serial) ? v.to_serial : v
      end
    end

    def to_serial
      to_h
    end

    def symbolize_keys_deep
      JSON.parse(to_serial.to_json, symbolize_names: true)
    end

    def materialized?(*keys)
      node = self
      keys.each do |key|
        return false unless node.respond_to?(:key?) && node.key?(key)

        node = node[key]
      end
      true
    end
  end

  class AutoNode
    def initialize(key)
      @key = key
      @backing = nil
    end

    def <<(value)
      ensure_array!
      @backing << value
    end

    def merge!(other)
      ensure_hash!
      other.each do |k, v|
        self[k] = v
      end
    end

    def []=(k, v)
      ensure_hash!
      @backing[k] = wrap(v)
    end

    def [](k)
      ensure_hash!
      @backing[k] ||= AutoNode.new(k)
    end

    def to_h
      raise TypeError, "Cannot call to_h on array-backed AutoNode (#{@key.inspect})" if @backing.is_a?(Array)

      serialize_hash
    end

    def to_a
      raise TypeError, "Cannot call to_a on hash-backed AutoNode (#{@key.inspect})" if @backing.is_a?(Hash)

      serialize_array
    end

    def to_serial
      case @backing
      when Hash then serialize_hash
      when Array then serialize_array
      else nil
      end
    end

    def inspect
      backing = @backing.nil? ? "nil" : @backing.inspect
      "#<AutoNode #{@key.inspect} => #{backing}>"
    end

    def as_json(*args)
      to_h
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    private

    def ensure_array!
      raise_type_conflict(:Hash) if @backing && !@backing.is_a?(Array)
      @backing ||= []
    end

    def ensure_hash!
      raise_type_conflict(:Array) if @backing && !@backing.is_a?(Hash)
      @backing ||= {}
    end

    def raise_type_conflict(existing)
      raise TypeError, "AutoNode #{@key.inspect} already used as #{existing}"
    end

    def wrap(value)
      case value
      when Hash
        value.transform_values { |v| wrap(v) }
      when Array
        value.map { |v| wrap(v) }
      else
        value
      end
    end

    def serialize_hash
      return {} unless @backing.is_a?(Hash)

      @backing.transform_values { |v| v.respond_to?(:to_serial) ? v.to_serial : v }
    end

    def serialize_array
      return [] unless @backing.is_a?(Array)

      @backing.map { |v| v.respond_to?(:to_serial) ? v.to_serial : v }
    end
  end
end
