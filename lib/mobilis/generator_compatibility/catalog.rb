# frozen_string_literal: true

require "json"

module Mobilis
  module GeneratorCompatibility
    class Catalog
      Invocation = Data.define(:generator, :version, :arguments, :required_paths, :target_paths)

      attr_reader :invocations

      def self.from_corpus(corpus_root)
        capture_path = File.join(corpus_root, "rspec-install", "default.json")
        capture = JSON.parse(File.read(capture_path))
        transformation = CapturedFileCreation.new(
          capture,
          required_paths: ["config/application.rb", "config/environment.rb"]
        )
        new.tap do |catalog|
          catalog.register(
            generator: capture.dig("generator", "identity"),
            version: capture.dig("generator", "version"),
            arguments: capture.dig("invocation", "arguments"),
            transformation:
          )
        end
      end

      def initialize(registry: Registry.new)
        @registry = registry
        @invocations = []
      end

      def register(generator:, version:, arguments:, transformation:)
        @registry.register(generator:, version:, arguments:, transformation:)
        @invocations << Invocation.new(
          generator:,
          version:,
          arguments: Array(arguments).map(&:to_s).freeze,
          required_paths: transformation.required_paths,
          target_paths: transformation.target_paths
        )
        self
      end

      def apply(generator:, version:, arguments:, workspace:)
        @registry.apply(generator:, version:, arguments:, workspace:)
      end
    end
  end
end
