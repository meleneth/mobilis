# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Model
    class LocalGem
      attr_reader :name, :path, :require_name, :files

      def initialize(name, path: nil, require_name: nil, files: [])
        @name = name
        @path = path || "../localgems/#{name}"
        @require_name = require_name
        @files = files
      end

      def write_file(path, content)
        files << Mobilis::Model::File.new(path, content)
        self
      end

      def gem_dependency
        Mobilis::Model::RubyGem.new(name, path: path, require_name: require_name)
      end

      def root_path
        path.sub(%r{\A\.\./}, "")
      end

      def write_files
        files.each do |file|
          target = ::File.join(root_path, file.path)
          dir = ::File.dirname(target)
          FileUtils.mkdir_p(dir)
          ::File.write(target, file.content)
        end
      end

      def to_h
        {
          type: self.class.name,
          name: name,
          path: path,
          require_name: require_name,
          files: files.map(&:to_h)
        }.compact
      end

      def self.from_h(hash)
        new(
          hash[:name],
          path: hash[:path],
          require_name: hash[:require_name],
          files: (hash[:files] || []).map { |file| Mobilis::Model::File.from_h(file) }
        )
      end
    end
  end
end
