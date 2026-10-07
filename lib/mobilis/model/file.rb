# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Model
    class File
      attr_reader :path, :content, :executable

      def initialize(path, content, executable: false)
        @path = path
        @content = content
        @executable = executable
      end

      def to_h
        {
          type: self.class.name,
          path: @path,
          content: @content,
          executable: @executable
        }
      end

      def write_file
        dir = ::File.dirname(@path)
        FileUtils.mkdir_p(dir)
        bytes = ::File.write(@path, @content)
        FileUtils.chmod("+x", @path) if executable
        bytes
      end

      def self.from_h(hash)
        new(hash[:path], hash[:content], executable: hash[:executable] == true)
      end

      def ppx_fields(dsl)
        dsl.simple_value "path", path
        dsl.simple_value "lines", content.lines.count
      end
    end
  end
end
