# frozen_string_literal: true

require "base64"
require "json"

module Mobilis
  module Browser
    class GeneratorCompatibility
      DEFAULT_CORPUS_ROOT = "/src/generator_compatibility/captures"

      def initialize(corpus_root: DEFAULT_CORPUS_ROOT)
        @catalog = Mobilis::GeneratorCompatibility::Catalog.from_corpus(corpus_root)
      end

      def manifests
        @catalog.invocations.map do |invocation|
          {
            generator: invocation.generator,
            version: invocation.version,
            arguments: invocation.arguments,
            input_paths: (invocation.required_paths + invocation.target_paths).uniq.sort
          }
        end
      end

      def plan(generator:, version:, arguments:, encoded_files:)
        files = encoded_files.filter_map do |path, encoded|
          [path, Base64.strict_decode64(encoded)] if encoded
        end.to_h
        workspace = Mobilis::GeneratorCompatibility::MemoryWorkspace.new(files)
        result = @catalog.apply(generator:, version:, arguments:, workspace:)
        {
          created: result.fetch(:created),
          unchanged: result.fetch(:unchanged),
          writes: workspace.writes.sort.to_h do |path, record|
            [path, {content: Base64.strict_encode64(record.fetch(:content)), mode: record.fetch(:mode)}]
          end
        }
      end
    end
  end
end
