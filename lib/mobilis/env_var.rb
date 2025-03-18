# frozen_string_literal: true

##
# EnvVar represents a normalized environment variable name.
# It automatically converts names to uppercase, replacing dashes and spaces with underscores.
# Provides convenience methods for building hierarchical names and shell references.
#
# @example
#   env = EnvVar.new("user-service")
#   env.raw         # => "USER_SERVICE"
#   env.to_s        # => "$USER_SERVICE"
#   env.ref         # => "${USER_SERVICE}"
#   env.child("db") # => EnvVar with raw = "USER_SERVICE_DB"
#
module Mobilis
  class EnvVar
    # The normalized environment variable name without `$` or braces.
    #
    # @return [String]
    attr_reader :raw

    ##
    # Factory method for creating an EnvVar from a string.
    #
    # @param name [String]
    # @return [EnvVar]
    def self.[](name)
      new(name)
    end

    ##
    # Create a new EnvVar.
    #
    # @param name [String] the initial name, which will be normalized
    def initialize(name)
      @raw = normalize(name)
    end

    ##
    # Return a child env var with an appended suffix.
    #
    # @param suffix [String]
    # @return [EnvVar]
    def child(suffix)
      EnvVar.new("#{@raw}_#{normalize(suffix)}")
    end

    ##
    # Return the variable name in `$VAR` format.
    #
    # @return [String]
    def to_s
      "$#{@raw}"
    end

    ##
    # Return the variable name in `${VAR}` format for shell reference.
    #
    # @return [String]
    def ref
      "${#{@raw}}"
    end

    private

    ##
    # Normalize a string to uppercase, underscores, and remove leading/trailing underscores.
    #
    # @param str [String]
    # @return [String]
    def normalize(str)
      str.to_s.strip.upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/^_+|_+$/, "")
    end
  end
end
