# frozen_string_literal: true

# Provides canonical Docker image tags for base components.
# Used by node generators to ensure consistent versions across environments.
module Mobilis
  module DockerImageRegistry
    # Canonical image tag mappings (single source of truth)
    IMAGE_TAGS = {
      ruby:     'ruby:3.4.2-bookworm',
      postgres: 'postgres:17.4-bookworm',
      mariadb:  'mariadb:11.7-ubi',
      redis:    'redis:7.4.2-bookworm'
    }.freeze

    # Returns the canonical image tag for a symbol (e.g., :ruby, :postgres)
    #
    # @param key [Symbol] the image key (e.g., :ruby, :postgres)
    # @return [String] the canonical Docker image tag
    def self.tag_for(key)
      IMAGE_TAGS.fetch(key) do
        raise ArgumentError, "No image tag defined for #{key.inspect}"
      end
    end

    # Returns all image mappings as a frozen hash
    #
    # @return [Hash<Symbol,String>]
    def self.all_tags
      IMAGE_TAGS.dup.freeze
    end
  end
end
