#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

runtime_file, application_file = ARGV
abort "usage: verify_runtime_compatibility.rb RUNTIME_CONFIG APPLICATION_MANIFEST" unless runtime_file && application_file

runtime = JSON.parse(File.read(runtime_file)).fetch("runtime")
application = JSON.parse(File.read(application_file)).fetch("compatible_runtime")
expected = {
  "package" => "mobilis-ruby-wasm",
  "package_version" => "2.10.1-ruby-4.0.10-rails-8.1.4.1-json-3.1.0"
}

expected.each do |field, value|
  abort "Ruby WASM runtime #{field} mismatch: expected #{value.inspect}, got #{runtime[field].inspect}" unless runtime[field] == value
  abort "Application #{field} mismatch: expected #{value.inspect}, got #{application[field].inspect}" unless application[field] == value
end
abort "Ruby WASM release mismatch: expected Ruby 4.0" unless runtime["ruby_version"] == "4.0"

puts "Runtime and application agree on dedicated Mobilis Ruby WASM identity"
