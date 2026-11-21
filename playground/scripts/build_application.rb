#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require_relative "application_artifact"

root, output = ARGV
abort "usage: build_application.rb ROOT OUTPUT_DIRECTORY" unless root && output

runtime_package = ENV.fetch("RUBY_WASM_RUNTIME_PACKAGE", "@ruby/4.0-wasm-wasi")
runtime_version = ENV.fetch("RUBY_WASM_RUNTIME_VERSION", "2.10.1")
result = MobilisPlayground::ApplicationArtifact.build(
  root:,
  runtime_package:,
  runtime_version:,
  load_paths: ["/gems/json_pure", "/gems/haml", "/gems/temple", "/gems/thor", "/gems/tilt", "/src/lib", "/src/playground/app"],
  boot_feature: "boot"
)

FileUtils.mkdir_p(output)
Dir.glob(File.join(output, "mobilis-app-*.tar")).each { |path| FileUtils.rm_f(path) }
artifact_name = File.basename(result.manifest.fetch(:artifact).fetch(:url))
File.binwrite(File.join(output, artifact_name), result.archive)
File.write(File.join(output, "mobilis-app-manifest.json"), JSON.generate(result.manifest) + "\n")
