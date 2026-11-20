# frozen_string_literal: true

module Mobilis
  module GeneratorCompatibility
    class MemoryWorkspace
      attr_reader :writes

      def initialize(files = {})
        @files = files.to_h.transform_keys(&:to_s).transform_values { |content| String(content).b }
        @writes = {}
      end

      def exist?(path)
        @files.key?(String(path))
      end
      alias file? exist?

      def read(path)
        @files.fetch(String(path))
      end

      def write(path, content, mode: nil)
        key = String(path)
        value = String(content).b
        @files[key] = value
        @writes[key] = {content: value, mode:}
      end
    end
  end
end
