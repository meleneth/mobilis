# frozen_string_literal: true

require "digest"
require "json"

module MobilisPlayground
  class ApplicationArtifact
    FORMAT = "mobilis-browser-application"
    VERSION = 1
    BLOCK_SIZE = 512
    MAX_FILES = 2_048
    MAX_FILE_SIZE = 16 * 1024 * 1024
    MAX_ARCHIVE_SIZE = 64 * 1024 * 1024

    Result = Data.define(:manifest, :archive)

    def self.build(root:, runtime_package:, runtime_version:, load_paths:, boot_feature:)
      new(
        root:,
        runtime_package:,
        runtime_version:,
        load_paths:,
        boot_feature:
      ).build
    end

    def initialize(root:, runtime_package:, runtime_version:, load_paths:, boot_feature:)
      @root = File.expand_path(root)
      @runtime_package = runtime_package
      @runtime_version = runtime_version
      @load_paths = load_paths
      @boot_feature = boot_feature
    end

    def build
      entries = source_entries
      archive = build_tar(entries)
      raise ArgumentError, "Application archive exceeds #{MAX_ARCHIVE_SIZE} bytes" if archive.bytesize > MAX_ARCHIVE_SIZE

      archive_sha256 = Digest::SHA256.hexdigest(archive)
      artifact_name = "mobilis-app-#{archive_sha256}.tar"
      manifest = {
        format: FORMAT,
        version: VERSION,
        application_version: archive_sha256,
        compatible_runtime: {
          package: @runtime_package,
          package_version: @runtime_version
        },
        artifact: {
          url: "/#{artifact_name}",
          size: archive.bytesize,
          sha256: archive_sha256,
          integrity: integrity(archive)
        },
        filesystem: {
          load_paths: @load_paths,
          boot_feature: @boot_feature,
          files: entries.map do |path, content|
            {path:, size: content.bytesize, sha256: Digest::SHA256.hexdigest(content)}
          end
        }
      }
      Result.new(manifest:, archive:)
    end

    private

    def source_entries
      raise ArgumentError, "Application root does not exist: #{@root}" unless Dir.exist?(@root)

      paths = Dir.glob("**/*", File::FNM_DOTMATCH, base: @root)
        .reject { |path| [".", ".."].include?(path) }
        .sort
      files = paths.filter_map do |path|
        absolute = File.join(@root, path)
        next if File.directory?(absolute)
        raise ArgumentError, "Application artifact only supports regular files: #{path}" unless File.file?(absolute) && !File.symlink?(absolute)

        safe_path = validate_path!(path)
        content = File.binread(absolute)
        raise ArgumentError, "Application file #{safe_path} exceeds #{MAX_FILE_SIZE} bytes" if content.bytesize > MAX_FILE_SIZE

        [safe_path, content]
      end
      raise ArgumentError, "Application artifact has too many files" if files.length > MAX_FILES
      raise ArgumentError, "Application artifact is empty" if files.empty?

      @load_paths.each do |load_path|
        relative = validate_absolute_load_path!(load_path)
        raise ArgumentError, "Application load path does not exist: #{load_path}" unless paths.include?(relative) && File.directory?(File.join(@root, relative))
      end
      files
    end

    def build_tar(entries)
      archive = String.new(encoding: Encoding::BINARY)
      entries.each do |path, content|
        archive << tar_header(path, content.bytesize)
        archive << content
        archive << ("\0" * (padded_size(content.bytesize) - content.bytesize))
      end
      archive << ("\0" * (2 * BLOCK_SIZE))
    end

    def tar_header(path, size)
      name, prefix = split_tar_path(path)
      header = "\0" * BLOCK_SIZE
      write_field(header, 0, 100, name)
      write_field(header, 100, 8, "0000644\0")
      write_field(header, 108, 8, "0000000\0")
      write_field(header, 116, 8, "0000000\0")
      write_field(header, 124, 12, format("%011o\0", size))
      write_field(header, 136, 12, "00000000000\0")
      write_field(header, 148, 8, "        ")
      write_field(header, 156, 1, "0")
      write_field(header, 257, 6, "ustar\0")
      write_field(header, 263, 2, "00")
      write_field(header, 345, 155, prefix)
      write_field(header, 148, 8, format("%06o\0 ", header.bytes.sum))
      header
    end

    def split_tar_path(path)
      return [path, ""] if path.bytesize <= 100

      split = path.rindex("/", 155)
      raise ArgumentError, "Application path is too long for ustar: #{path}" unless split

      prefix = path.byteslice(0, split)
      name = path.byteslice(split + 1, path.bytesize)
      raise ArgumentError, "Application path is too long for ustar: #{path}" if prefix.bytesize > 155 || name.bytesize > 100

      [name, prefix]
    end

    def validate_path!(path)
      components = path.split("/", -1)
      invalid = path.empty? || path.start_with?("/", "\\") || path.include?("\0") || path.include?("\\") ||
        components.any? { |component| component.empty? || component == "." || component == ".." }
      raise ArgumentError, "Unsafe application path #{path.inspect}" if invalid

      split_tar_path(path)
      path
    end

    def validate_absolute_load_path!(path)
      raise ArgumentError, "Application load path must be absolute: #{path.inspect}" unless path.is_a?(String) && path.start_with?("/")

      validate_path!(path.delete_prefix("/"))
    end

    def padded_size(size)
      ((size + BLOCK_SIZE - 1) / BLOCK_SIZE) * BLOCK_SIZE
    end

    def write_field(header, offset, length, value)
      raise ArgumentError, "Tar field is too long" if value.bytesize > length

      header[offset, length] = value.ljust(length, "\0")
    end

    def integrity(content)
      "sha256-#{[Digest::SHA256.digest(content)].pack("m0")}"
    end
  end
end
