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
        result = {
          type: self.class.name,
          path: @path,
          executable: @executable
        }
        text = @content.dup.force_encoding(Encoding::UTF_8)
        if text.valid_encoding?
          result[:content] = text
        else
          result[:content_base64] = [@content].pack("m0")
        end
        result
      end

      def write_file
        dir = ::File.dirname(@path)
        FileUtils.mkdir_p(dir)
        bytes = ::File.write(@path, @content)
        FileUtils.chmod("+x", @path) if executable
        bytes
      end

      def self.from_h(hash)
        content = if hash.key?(:content_base64)
          encoded = hash[:content_base64]
          raise ArgumentError, "File content_base64 must be a String" unless encoded.is_a?(String)

          decode_base64(encoded)
        else
          hash.fetch(:content)
        end
        new(hash[:path], content, executable: hash[:executable] == true)
      end

      def self.decode_base64(payload)
        valid = payload.is_a?(String) && (payload.empty? || (
          (payload.bytesize % 4).zero? &&
          payload.match?(/\A(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?\z/)
        ))
        raise ArgumentError, "File content_base64 is not strict Base64" unless valid

        payload.unpack1("m0") || raise(ArgumentError, "File content_base64 could not be decoded")
      end

      def ppx_fields(dsl)
        dsl.simple_value "path", path
        dsl.simple_value "lines", content.lines.count
      end
    end
  end
end
