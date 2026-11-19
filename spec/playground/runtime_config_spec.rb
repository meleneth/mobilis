# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "playground runtime configuration" do
  let(:script) { File.expand_path("../../playground/scripts/build_runtime_config.rb", __dir__) }

  it "pins the official runtime URL and records the exact package bytes" do
    Dir.mktmpdir do |directory|
      runtime = File.join(directory, "ruby.wasm")
      output = File.join(directory, "runtime-config.json")
      File.binwrite(runtime, "standard ruby wasm")
      stdout, _stderr, status = Open3.capture3(RbConfig.ruby, script, runtime, output)

      expect(stdout).to eq("")
      expect(status).to be_success
      config = JSON.parse(File.read(output))
      expect(config.fetch("runtime")).to include(
        "package" => "@ruby/4.0-wasm-wasi",
        "package_version" => "2.10.1",
        "ruby_version" => "4.0",
        "url" => "https://cdn.jsdelivr.net/npm/@ruby/4.0-wasm-wasi@2.10.1/dist/ruby+stdlib.wasm",
        "size" => 18,
        "sha256" => Digest::SHA256.hexdigest("standard ruby wasm")
      )
    end
  end

  it "supports an explicit same-version local development URL without changing integrity" do
    Dir.mktmpdir do |directory|
      runtime = File.join(directory, "ruby.wasm")
      output = File.join(directory, "runtime-config.json")
      File.binwrite(runtime, "standard ruby wasm")
      _stdout, _stderr, status = Open3.capture3(
        {"RUBY_WASM_RUNTIME_URL" => "/vendor/ruby+stdlib.wasm"},
        RbConfig.ruby, script, runtime, output
      )

      expect(status).to be_success
      expect(JSON.parse(File.read(output)).dig("runtime", "url")).to eq("/vendor/ruby+stdlib.wasm")
    end
  end
end
