# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Browser
    class Generator
      Result = Data.define(:root, :files)

      def initialize(workspace: "/tmp/mobilis-playground")
        @workspace = workspace
      end

      def call(system)
        caller_directory = Dir.pwd
        FileUtils.rm_rf(@workspace)
        FileUtils.mkdir_p(@workspace)

        directory = Mobilis::Services::Directory.new(@workspace)
        root = Mobilis::Manifest.new(system, directory_service: directory).materialize_static
        files = Dir.glob("**/*", File::FNM_DOTMATCH, base: root)
          .reject { |path| path == "." || path == ".." || File.directory?(File.join(root, path)) }
          .sort
          .to_h { |path| [path, File.binread(File.join(root, path))] }
        Result.new(root:, files:)
      ensure
        Dir.chdir(caller_directory) if caller_directory
      end
    end
  end
end
