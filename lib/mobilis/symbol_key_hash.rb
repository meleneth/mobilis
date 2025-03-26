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

    def fetch(key, default_value = nil, &block)
      sym_key = key.to_sym
      if block
        super(sym_key) { |k| block.call(k) }
      elsif default_value

        super(sym_key, default_value)
      else
        super(sym_key)
      end
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
