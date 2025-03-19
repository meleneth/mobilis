# frozen_string_literal: true

module Mobilis
  # A Hash subclass that automatically converts all keys to symbols
  # on assignment, lookup, and fetch. Useful for config and env structures
  # where symbol keys are preferred.
  class SymbolKeyHash < Hash
    def []=(key, value)
      super(key.to_sym, value)
    end

    def [](key)
      super(key.to_sym)
    end

    def fetch(key, *args, &block)
      super(key.to_sym, *args, &block)
    end

    def key?(key)
      super(key.to_sym)
    end

    def merge!(other_hash)
      other_hash.each { |k, v| self[k] = v }
      self
    end

    def update(other_hash)
      merge!(other_hash)
    end
  end
end
