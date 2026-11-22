#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"

source_dir, output_dir = ARGV
abort "Usage: build_examples.rb SCRIPTS_DIR OUTPUT_DIR" unless source_dir && output_dir
FileUtils.mkdir_p(output_dir)
entries = Dir.glob("[0-9][0-9]_*.rb", base: source_dir).sort.map do |name|
  bytes = File.binread(File.join(source_dir, name))
  abort "Non-UTF-8 example: #{name}" unless bytes.force_encoding(Encoding::UTF_8).valid_encoding?
  File.binwrite(File.join(output_dir, name), bytes)
  {file: name, label: name.delete_suffix(".rb").tr("_", " ")}
end
abort "No numbered examples found in #{source_dir}" if entries.empty?
File.write(File.join(output_dir, "index.json"), JSON.pretty_generate(entries) + "\n")
