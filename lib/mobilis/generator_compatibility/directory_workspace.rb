# frozen_string_literal: true

require "fileutils"
require "pathname"

module Mobilis
  module GeneratorCompatibility
    class UnsafePathError < ArgumentError; end

    class DirectoryWorkspace
      def initialize(root)
        expanded = File.expand_path(root)
        FileUtils.mkdir_p(expanded)
        @root = File.realpath(expanded)
      end

      def exist?(path)
        File.file?(resolve(path))
      end

      def read(path)
        File.binread(resolve(path))
      end

      def file?(path)
        File.file?(resolve(path))
      end

      def write(path, content, mode: nil)
        destination = resolve(path)
        FileUtils.mkdir_p(File.dirname(destination))
        File.binwrite(destination, content)
        File.chmod(mode.to_i(8), destination) if mode
      end

      private

      def resolve(path)
        relative = Pathname.new(String(path))
        raise UnsafePathError, "Workspace paths must be relative: #{path}" if relative.absolute?
        raise UnsafePathError, "Workspace path cannot be empty" if relative.to_s.empty? || relative.to_s == "."

        current = @root
        relative.each_filename do |component|
          raise UnsafePathError, "Workspace path escapes root: #{path}" if component == ".."

          current = File.join(current, component)
          raise UnsafePathError, "Workspace path traverses a symlink: #{path}" if File.symlink?(current)
        end

        destination = File.expand_path(current)
        unless destination == @root || destination.start_with?("#{@root}#{File::SEPARATOR}")
          raise UnsafePathError, "Workspace path escapes root: #{path}"
        end

        destination
      end
    end
  end
end
