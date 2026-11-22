# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Browser
    class Generator
      Result = Data.define(:root, :files, :steps)

      def initialize(workspace: "mobilis-playground")
        @workspace = workspace
      end

      def call(system)
        caller_directory = Dir.pwd
        FileUtils.rm_rf(@workspace)
        FileUtils.mkdir_p(@workspace)

        directory = Mobilis::Services::Directory.new(@workspace)
        steps = []
        root = Mobilis::Browser::FileSystemCompatibility.without_posix_permissions do
          Mobilis::Manifest.new(system, directory_service: directory).materialize_browser(
            on_checkpoint: ->(message, writes, deletes) { steps << {message:, writes:, deletes:} }
          )
        end
        files = Dir.glob("**/*", File::FNM_DOTMATCH, base: root)
          .reject { |path| path == "." || path == ".." || File.directory?(File.join(root, path)) }
          .sort
          .to_h { |path| [path, File.binread(File.join(root, path))] }
        Result.new(root:, files:, steps:)
      ensure
        Dir.chdir(caller_directory) if caller_directory
      end
    end
  end
end
