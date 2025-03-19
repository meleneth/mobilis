require "fileutils"

module Mobilis
  class OutputFile
    attr_reader :filename

    def initialize(filename)
      @filename = filename
    end

    def render
      raise NotImplementedError, "#{self.class} must implement #render"
    end

    def write_to(dir, force_overwrite: false)
      full_path = File.join(dir, filename)
      FileUtils.mkdir_p(File.dirname(full_path))

      if File.exist?(full_path) && !force_overwrite
        raise "Refusing to overwrite existing file: #{full_path}. Pass force_overwrite: true to override."
      end

      File.write(full_path, render)
    end
  end
end
