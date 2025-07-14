# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Model
    class File
      attr_reader :path, :content

      def initialize(path, content)
        @path = path
        @content = content
      end

      def to_h
        {
          type: self.class.name,
          path: @path,
          content: @content
        }
      end

      def write_file
        dir = ::File.dirname(@path)
        FileUtils.mkdir_p(dir)
        ::File.write(@path, @content)
      end

      def self.from_h(hash)
        new(hash[:path], hash[:content])
      end

      def ppx_fields(dsl)
        dsl.simple_value "path", path
        dsl.simple_value "lines", content.lines.count
      end
    end
  end
end
