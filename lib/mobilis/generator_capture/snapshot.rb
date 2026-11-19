# frozen_string_literal: true

require "base64"
require "digest"
require "find"
require "json"
require "pathname"

module Mobilis
  module GeneratorCapture
    class Snapshot
      attr_reader :entries

      def self.capture(root)
        root = File.expand_path(root)
        records = []

        Find.find(root) do |absolute_path|
          next if absolute_path == root

          relative_path = Pathname.new(absolute_path).relative_path_from(Pathname.new(root)).to_s
          status = File.lstat(absolute_path)
          if status.file?
            records << file_record(relative_path, absolute_path, status)
          elsif status.symlink?
            records << {
              "path" => relative_path,
              "type" => "symlink",
              "mode" => mode(status),
              "target" => File.readlink(absolute_path)
            }
          end
        end

        new(records.sort_by { |entry| entry.fetch("path") })
      end

      def self.file_record(relative_path, absolute_path, status)
        bytes = File.binread(absolute_path)
        text = bytes.dup.force_encoding(Encoding::UTF_8)
        record = {
          "path" => relative_path,
          "type" => "file",
          "mode" => mode(status),
          "sha256" => Digest::SHA256.hexdigest(bytes)
        }

        if text.valid_encoding? && !bytes.include?("\0")
          record.merge("encoding" => "utf-8", "content" => text)
        else
          record.merge("encoding" => "base64", "content" => Base64.strict_encode64(bytes))
        end
      end

      def self.mode(status)
        format("%04o", status.mode & 0o7777)
      end

      private_class_method :file_record, :mode

      def initialize(entries)
        @entries = entries.freeze
      end

      def fingerprint
        Digest::SHA256.hexdigest(JSON.generate(entries))
      end

      def delta_to(other)
        before = entries.to_h { |entry| [entry.fetch("path"), entry] }
        after = other.entries.to_h { |entry| [entry.fetch("path"), entry] }

        (before.keys | after.keys).sort.filter_map do |path|
          if !before.key?(path)
            {"operation" => "create", "path" => path, "after" => after.fetch(path)}
          elsif !after.key?(path)
            {"operation" => "delete", "path" => path, "before" => before.fetch(path)}
          elsif before.fetch(path) != after.fetch(path)
            {
              "operation" => "modify",
              "path" => path,
              "before" => before.fetch(path),
              "after" => after.fetch(path)
            }
          end
        end
      end
    end
  end
end
