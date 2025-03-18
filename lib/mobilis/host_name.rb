# frozen_string_literal: true

##
# HostName represents a normalized host or DNS name.
# It converts input strings to lowercase, splits camel-case words, and replaces spaces/underscores with dashes.
# Supports appending child segments using `.child()`.
#
# @example
#   host = HostName.new("UserDB")
#   host.raw         # => "user-db"
#   host.child("replica") # => "user-db-replica"
#
module Mobilis
  class HostName
    # The normalized hostname string
    #
    # @return [String]
    attr_reader :raw

    ##
    # Factory method for creating a HostName from a string.
    #
    # @param name [String]
    # @return [HostName]
    def self.[](name)
      new(name)
    end

    ##
    # Create a new HostName.
    #
    # @param name [String] the initial name to normalize
    def initialize(name)
      @raw = normalize(name)
    end

    ##
    # Append a suffix as a child hostname segment.
    #
    # @param suffix [String]
    # @return [HostName]
    def child(suffix)
      HostName.new("#{@raw}-#{normalize(suffix)}")
    end

    ##
    # Return the hostname string
    #
    # @return [String]
    def to_s
      @raw
    end

    private

    ##
    # Normalize a string:
    # - Add dashes between camel-case boundaries
    # - Convert to lowercase
    # - Replace non-alphanumeric with dashes
    # - Trim leading/trailing dashes
    #
    # @param str [String]
    # @return [String]
    def normalize(str)
      str
        .to_s
        .strip
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2') # split between acronym & next word
        .gsub(/([a-z0-9])([A-Z])/, '\1-\2')    # also split between normal lowercase-uppercase transition
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/^-+|-+$/, "")
    end
  end
end
