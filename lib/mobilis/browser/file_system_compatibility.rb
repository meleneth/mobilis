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

      File.singleton_class.prepend(IgnoreUnsupportedFileChmod)
      FileUtils.singleton_class.prepend(IgnoreUnsupportedFileUtilsChmod)
    end
  end
end
