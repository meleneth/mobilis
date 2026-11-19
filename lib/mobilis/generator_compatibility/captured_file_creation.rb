# frozen_string_literal: true

require "base64"

module Mobilis
  module GeneratorCompatibility
    class InvalidCaptureError < ArgumentError; end
    class WorkspaceConflictError < StandardError; end

    class CapturedFileCreation
      def initialize(capture, required_paths: [])
        @capture = capture
        @required_paths = required_paths.map(&:to_s).freeze
        validate_capture!
      end

      def apply(workspace)
        missing = @required_paths.reject { |path| workspace.file?(path) }
        unless missing.empty?
          raise WorkspaceConflictError, "Generator prerequisites are missing: #{missing.join(", ")}"
        end

        planned = entries.map do |entry|
          after = entry.fetch("after")
          content = decode(after)
          path = entry.fetch("path")
          if workspace.exist?(path)
            existing = workspace.read(path)
            unless existing == content
              raise WorkspaceConflictError, "Refusing to overwrite changed workspace file: #{path}"
            end
            [path, content, after.fetch("mode"), false]
          else
            [path, content, after.fetch("mode"), true]
          end
        end

        planned.each do |path, content, mode, write|
          workspace.write(path, content, mode:) if write
        end

        {
          created: planned.filter_map { |path, _content, _mode, write| path if write },
          unchanged: planned.filter_map { |path, _content, _mode, write| path unless write }
        }
      end

      private

      def entries
        @capture.dig("result", "delta")
      end

      def validate_capture!
        raise InvalidCaptureError, "Compatibility evidence must be a successful capture" unless @capture.dig("result", "success")
        unless entries.all? { |entry| entry.fetch("operation") == "create" && entry.dig("after", "type") == "file" }
          raise InvalidCaptureError, "Captured file creation only supports newly created regular files"
        end
      end

      def decode(record)
        case record.fetch("encoding")
        when "utf-8" then record.fetch("content").b
        when "base64" then Base64.strict_decode64(record.fetch("content"))
        else raise InvalidCaptureError, "Unsupported captured content encoding: #{record.fetch("encoding")}"
        end
      end
    end
  end
end
