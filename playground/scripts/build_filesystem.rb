# frozen_string_literal: true

require "base64"
require "json"

root, output = ARGV
abort "usage: build_filesystem.rb ROOT OUTPUT" unless root && output

files = Dir.glob("**/*", File::FNM_DOTMATCH, base: root)
  .reject { |path| path == "." || path == ".." || File.directory?(File.join(root, path)) }
  .sort
  .to_h { |path| [path, Base64.strict_encode64(File.binread(File.join(root, path)))] }

File.write(output, JSON.generate(files))
