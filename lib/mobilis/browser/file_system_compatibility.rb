# frozen_string_literal: true

module Mobilis
  module Browser
    module FileSystemCompatibility
      module IgnoreUnsupportedFileChmod
        def chmod(*arguments)
          super
        rescue Errno::ENOSYS, Errno::ENOTSUP
          raise unless Mobilis::Browser::FileSystemCompatibility.active?

          0
        end
      end

      module IgnoreUnsupportedFileUtilsChmod
        def chmod(*arguments, **keywords)
          super
        rescue Errno::ENOSYS, Errno::ENOTSUP
          raise unless Mobilis::Browser::FileSystemCompatibility.active?

          arguments.first
        end
      end

      # WASI's file access predicate may report false for writable
      # preopened directories. Check actual filesystem capability rather
      # than globally lying about permissions. This is limited to the
      # duration of browser generation.
      module ProbeWritableDirectory
        def writable?(path)
          original = super
          return original unless Mobilis::Browser::FileSystemCompatibility.active?
          return true if original
          return false unless File.directory?(path)

          probe_path = File.join(path, ".mobilis-wasi-writable-#{Process.pid}-#{Random.rand(1_000_000)}")
          begin
            File.open(probe_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) {}
            true
          rescue SystemCallError
            false
          ensure
            File.unlink(probe_path) if File.file?(probe_path)
          end
        end
      end

      class << self
        def active?
          @active == true
        end

        def without_posix_permissions
          previous = @active
          @active = true
          yield
        ensure
          @active = previous
        end
      end

      File.singleton_class.prepend(ProbeWritableDirectory)
      File.singleton_class.prepend(IgnoreUnsupportedFileChmod)
      FileUtils.singleton_class.prepend(IgnoreUnsupportedFileUtilsChmod)
    end
  end
end
