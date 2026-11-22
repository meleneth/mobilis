# frozen_string_literal: true

require "digest"
require "json"

module Mobilis
  class EmbeddedArchive
    FORMAT = "mobilis-embedded-archive"
    VERSION = 1
    MANIFEST_PATH = ".mobilis-archive.json"
    BLOCK_SIZE = 512
    MAX_ENCODED_SIZE = 8 * 1024 * 1024
    MAX_DECODED_SIZE = 6 * 1024 * 1024
    MAX_FILE_SIZE = 2 * 1024 * 1024
    MAX_ENTRIES = 512

    Entry = Data.define(:path, :content, :content_type, :sha256, :executable)

    class Bundle
      attr_reader :entries, :entrypoint, :dependencies, :payload

      def initialize(entries:, entrypoint:, dependencies:, payload: nil)
        @entries = entries.freeze
        @entrypoint = entrypoint
        @dependencies = dependencies.freeze
        @payload = payload
      end

      def files
        entries.to_h { |entry| [entry.path, entry.content] }
      end

      def entry(path)
        entries.find { |candidate| candidate.path == path }
      end
    end

    class << self
      def pack(files:, entrypoint: nil, dependencies: [])
        entries = normalize_entries(files)
        validate_metadata!(entries, entrypoint, dependencies)
        manifest = manifest_for(entries, entrypoint, dependencies)
        # @type var members: Array[[String, String, bool]]
        members = [[MANIFEST_PATH, JSON.generate(manifest) + "\n", false]]
        members.concat(entries.map { |entry| [entry.path, entry.content, entry.executable] })
        tar = build_tar(members)
        raise ArgumentError, "Embedded archive exceeds #{MAX_DECODED_SIZE} decoded bytes" if tar.bytesize > MAX_DECODED_SIZE
        encoded = strict_encode64(tar)
        raise ArgumentError, "Embedded archive exceeds #{MAX_ENCODED_SIZE} encoded bytes" if encoded.bytesize > MAX_ENCODED_SIZE

        encoded
      end

      def unpack(payload)
        raise ArgumentError, "Embedded archive payload must be Base64 text" unless payload.is_a?(String)
        raise ArgumentError, "Embedded archive exceeds #{MAX_ENCODED_SIZE} encoded bytes" if payload.bytesize > MAX_ENCODED_SIZE

        tar = strict_decode64(payload)
        raise ArgumentError, "Embedded archive exceeds #{MAX_DECODED_SIZE} decoded bytes" if tar.bytesize > MAX_DECODED_SIZE

        members = read_tar(tar)
        manifest_bytes, = members.delete(MANIFEST_PATH)
        raise ArgumentError, "Embedded archive is missing #{MANIFEST_PATH}" unless manifest_bytes

        manifest = JSON.parse(manifest_bytes, symbolize_names: true)
        validate_manifest!(manifest, members)
        entries = manifest.fetch(:files).map do |record|
          content, mode = members.fetch(record.fetch(:path))
          Entry.new(
            path: record.fetch(:path),
            content:,
            content_type: record.fetch(:content_type),
            sha256: record.fetch(:sha256),
            executable: mode == 0o755
          )
        end
        Bundle.new(
          entries:,
          entrypoint: manifest[:entrypoint],
          dependencies: manifest.fetch(:dependencies),
          payload:
        )
      rescue ArgumentError
        raise
      rescue JSON::ParserError => error
        raise ArgumentError, "Embedded archive manifest is invalid JSON: #{error.message}"
      end

      def replace(payload, path, content)
        bundle = unpack(payload)
        existing = bundle.entry(path)
        raise ArgumentError, "Embedded archive has no member #{path}" unless existing

        files = bundle.entries.to_h do |entry|
          value = entry.path == path ? content : entry.content
          [entry.path, {content: value, executable: entry.executable}]
        end
        pack(files:, entrypoint: bundle.entrypoint, dependencies: bundle.dependencies)
      end

      private

      def strict_encode64(content)
        [content].pack("m0")
      end

      def strict_decode64(payload)
        valid = payload.empty? || (
          (payload.bytesize % 4).zero? &&
          payload.match?(/\A(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?\z/)
        )
        raise ArgumentError, "Embedded archive payload is not strict Base64" unless valid

        decoded = payload.unpack1("m0")
        raise ArgumentError, "Embedded archive payload could not be decoded" unless decoded.is_a?(String)

        decoded
      end

      def normalize_entries(files)
        raise ArgumentError, "Embedded archive files must be a Hash" unless files.is_a?(Hash)
        raise ArgumentError, "Embedded archive has too many entries" if files.length > MAX_ENTRIES

        files.map do |path, value|
          path = validate_path!(path)
          raise ArgumentError, "#{MANIFEST_PATH} is reserved" if path == MANIFEST_PATH

          options = value.is_a?(Hash) ? value : {content: value}
          content = options.fetch(:content).to_s.b
          raise ArgumentError, "Embedded archive member #{path} exceeds #{MAX_FILE_SIZE} bytes" if content.bytesize > MAX_FILE_SIZE

          Entry.new(
            path:,
            content:,
            content_type: content_type(content),
            sha256: Digest::SHA256.hexdigest(content),
            executable: options[:executable] == true
          )
        end.sort_by(&:path)
      end

      def validate_metadata!(entries, entrypoint, dependencies)
        if entrypoint
          entrypoint = validate_path!(entrypoint)
          raise ArgumentError, "Archive entrypoint #{entrypoint} is not a member" unless entries.any? { |entry| entry.path == entrypoint }
        end
        raise ArgumentError, "Archive dependencies must be an Array of strings" unless dependencies.is_a?(Array) && dependencies.all? { |item| item.is_a?(String) }
      end

      def manifest_for(entries, entrypoint, dependencies)
        {
          format: FORMAT,
          version: VERSION,
          entrypoint:,
          dependencies: dependencies.sort,
          files: entries.map do |entry|
            {
              path: entry.path,
              size: entry.content.bytesize,
              sha256: entry.sha256,
              content_type: entry.content_type,
              mode: entry.executable ? "0755" : "0644"
            }
          end
        }
      end

      def build_tar(members)
        tar = String.new(capacity: members.sum { |_path, content, _executable| BLOCK_SIZE + padded_size(content.bytesize) } + (2 * BLOCK_SIZE), encoding: Encoding::BINARY)
        members.each do |path, content, executable|
          content = content.b
          tar << tar_header(path, content.bytesize, executable ? 0o755 : 0o644)
          tar << content
          tar << ("\0" * (padded_size(content.bytesize) - content.bytesize))
        end
        tar << ("\0" * (2 * BLOCK_SIZE))
      end

      def tar_header(path, size, mode)
        name, prefix = split_tar_path(path)
        header = "\0" * BLOCK_SIZE
        write_field(header, 0, 100, name)
        write_field(header, 100, 8, format("%07o\0", mode))
        write_field(header, 108, 8, "0000000\0")
        write_field(header, 116, 8, "0000000\0")
        write_field(header, 124, 12, format("%011o\0", size))
        write_field(header, 136, 12, "00000000000\0")
        write_field(header, 148, 8, "        ")
        write_field(header, 156, 1, "0")
        write_field(header, 257, 6, "ustar\0")
        write_field(header, 263, 2, "00")
        write_field(header, 345, 155, prefix)
        checksum = header.bytes.sum
        write_field(header, 148, 8, format("%06o\0 ", checksum))
        header
      end

      def read_tar(tar)
        raise ArgumentError, "Embedded archive is not a complete tar stream" unless tar.bytesize >= 2 * BLOCK_SIZE && (tar.bytesize % BLOCK_SIZE).zero?

        members = {}
        offset = 0
        terminated = false
        while offset + BLOCK_SIZE <= tar.bytesize
          header = tar.byteslice(offset, BLOCK_SIZE)
          raise ArgumentError, "Truncated embedded archive tar header" unless header
          offset += BLOCK_SIZE
          if header == "\0" * BLOCK_SIZE
            second = tar.byteslice(offset, BLOCK_SIZE)
            raise ArgumentError, "Embedded archive has an incomplete tar terminator" unless second == "\0" * BLOCK_SIZE
            offset += BLOCK_SIZE
            terminated = true
            break
          end

          validate_tar_header!(header)
          path = tar_path(header)
          raise ArgumentError, "Duplicate embedded archive member #{path}" if members.key?(path)
          type = required_byteslice(header, 156, 1)
          raise ArgumentError, "Unsupported tar entry type #{type.inspect} for #{path}" unless ["0", "\0"].include?(type)

          size = octal_field(header, 124, 12, "size")
          mode = octal_field(header, 100, 8, "mode")
          raise ArgumentError, "Invalid mode for #{path}" unless [0o644, 0o755].include?(mode)
          raise ArgumentError, "Embedded archive member #{path} exceeds #{MAX_FILE_SIZE} bytes" if size > MAX_FILE_SIZE
          raise ArgumentError, "Truncated embedded archive member #{path}" if offset + padded_size(size) > tar.bytesize

          content = tar.byteslice(offset, size)
          raise ArgumentError, "Truncated embedded archive member #{path}" unless content
          offset += padded_size(size)
          members[path] = [content, mode]
          raise ArgumentError, "Embedded archive has too many entries" if members.length > MAX_ENTRIES + 1
        end
        raise ArgumentError, "Embedded archive has no tar terminator" unless terminated
        raise ArgumentError, "Embedded archive contains trailing nonzero data" unless tar.byteslice(offset, tar.bytesize - offset).to_s.bytes.all?(&:zero?)

        members
      end

      def validate_tar_header!(header)
        expected = octal_field(header, 148, 8, "checksum")
        copy = header.dup
        copy[148, 8] = "        "
        raise ArgumentError, "Embedded archive tar checksum mismatch" unless copy.bytes.sum == expected
        raise ArgumentError, "Embedded archive must use ustar headers" unless header.byteslice(257, 6) == "ustar\0"
      end

      def validate_manifest!(manifest, members)
        raise ArgumentError, "Unsupported embedded archive format" unless manifest[:format] == FORMAT
        raise ArgumentError, "Unsupported embedded archive version #{manifest[:version]}" unless manifest[:version] == VERSION
        records = manifest[:files]
        raise ArgumentError, "Embedded archive manifest files must be an Array" unless records.is_a?(Array)
        raise ArgumentError, "Embedded archive dependencies must be an Array of strings" unless manifest[:dependencies].is_a?(Array) && manifest[:dependencies].all? { |item| item.is_a?(String) }
        expected_paths = records.map { |record| validate_path!(record.fetch(:path)) }
        raise ArgumentError, "Embedded archive manifest has duplicate paths" unless expected_paths.uniq.length == expected_paths.length
        raise ArgumentError, "Embedded archive manifest does not match tar members" unless expected_paths.sort == members.keys.sort

        records.each do |record|
          path = record.fetch(:path)
          content, mode = members.fetch(path)
          raise ArgumentError, "Embedded archive size mismatch for #{path}" unless record.fetch(:size) == content.bytesize
          raise ArgumentError, "Embedded archive integrity check failed for #{path}" unless record.fetch(:sha256) == Digest::SHA256.hexdigest(content)
          expected_mode = record.fetch(:mode) == "0755" ? 0o755 : 0o644
          raise ArgumentError, "Embedded archive mode mismatch for #{path}" unless mode == expected_mode
          raise ArgumentError, "Embedded archive content type mismatch for #{path}" unless record.fetch(:content_type) == content_type(content)
        end
        if manifest[:entrypoint]
          entrypoint = validate_path!(manifest[:entrypoint])
          raise ArgumentError, "Archive entrypoint #{entrypoint} is not a member" unless members.key?(entrypoint)
        end
      rescue KeyError => error
        raise ArgumentError, "Embedded archive manifest is missing #{error.key}"
      end

      def validate_path!(path)
        path = path.to_s
        components = path.split("/", -1)
        invalid = path.empty? || path.start_with?("/", "\\") || path.include?("\0") || path.include?("\\") ||
          components.any? { |component| component.empty? || component == "." || component == ".." }
        raise ArgumentError, "Unsafe embedded archive path #{path.inspect}" if invalid
        split_tar_path(path)
        path
      end

      def split_tar_path(path)
        return [path, ""] if path.bytesize <= 100

        split = path.rindex("/", 155)
        while split && (path.bytesize - split - 1 > 100)
          split = path.rindex("/", split - 1)
        end
        raise ArgumentError, "Embedded archive path is too long: #{path}" unless split

        prefix = path.byteslice(0, split)
        name = path.byteslice(split + 1, path.bytesize)
        raise ArgumentError, "Embedded archive path is too long: #{path}" unless prefix && name && prefix.bytesize <= 155

        [name, prefix]
      end

      def tar_path(header)
        name = null_terminated(required_byteslice(header, 0, 100))
        prefix = null_terminated(required_byteslice(header, 345, 155))
        validate_path!(prefix.empty? ? name : "#{prefix}/#{name}")
      end

      def required_byteslice(value, offset, length)
        value.byteslice(offset, length) || raise(ArgumentError, "Truncated embedded archive tar field")
      end

      def null_terminated(value)
        value.split("\0", 2).first || ""
      end

      def octal_field(header, offset, length, label)
        value = null_terminated(required_byteslice(header, offset, length)).strip
        raise ArgumentError, "Invalid tar #{label}" unless value.match?(/\A[0-7]+\z/)

        value.to_i(8)
      end

      def write_field(header, offset, length, value)
        raise ArgumentError, "Tar field overflow" if value.bytesize > length

        header[offset, length] = value.ljust(length, "\0")
      end

      def padded_size(size)
        ((size + BLOCK_SIZE - 1) / BLOCK_SIZE) * BLOCK_SIZE
      end

      def content_type(content)
        text = content.dup.force_encoding(Encoding::UTF_8)
        text.valid_encoding? && !text.include?("\0") ? "text/plain; charset=utf-8" : "application/octet-stream"
      end
    end
  end
end
