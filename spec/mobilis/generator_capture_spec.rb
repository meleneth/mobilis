# frozen_string_literal: true

require "spec_helper"
require "mobilis/generator_capture"
require "tmpdir"

RSpec.describe Mobilis::GeneratorCapture do
  def definition(fixture, name: "example", arguments: [], script: nil)
    script ||= 'root, value = ARGV; File.write(File.join(root, "generated.txt"), value || "default")'
    described_class.define(name) do
      generator "example:install", version: "1.2.3"
      fixture "minimal", path: fixture
      command RbConfig.ruby, "-e", script, "{workspace}"
      arguments(*arguments)
      environment "CAPTURE_ENV" => "stable"
      runtime "ruby_version" => RUBY_VERSION
    end
  end

  it "captures deterministic filesystem effects from a clean fixture" do
    Dir.mktmpdir("capture-fixture") do |fixture|
      File.write(File.join(fixture, "original.txt"), "original\n")
      runner = Mobilis::GeneratorCapture::Runner.new

      first = runner.run(definition(fixture, arguments: ["changed"]))
      second = runner.run(definition(fixture, arguments: ["changed"]))

      expect(first).to eq(second)
      expect(first.dig("fixture", "files").map { |entry| entry.fetch("path") }).to eq(["original.txt"])
      expect(first.dig("result", "delta")).to contain_exactly(
        include("operation" => "create", "path" => "generated.txt", "after" => include("content" => "changed"))
      )
      expect(File.read(File.join(fixture, "original.txt"))).to eq("original\n")
    end
  end

  it "records failed invocations as failures" do
    Dir.mktmpdir("capture-fixture") do |fixture|
      capture = Mobilis::GeneratorCapture::Runner.new.run(
        definition(fixture, script: 'warn "expected failure"; exit 7')
      )

      expect(capture.dig("result", "success")).to be(false)
      expect(capture.dig("result", "exit_status")).to eq(7)
      expect(capture.dig("result", "stderr")).to end_with("expected failure\n")
    end
  end

  it "compares successful argument variations without duplicating file contents" do
    Dir.mktmpdir("capture-fixture") do |fixture|
      runner = Mobilis::GeneratorCapture::Runner.new
      baseline = runner.run(definition(fixture, name: "baseline", arguments: ["one"]))
      variant = runner.run(definition(fixture, name: "variant", arguments: ["two"]))

      comparison = Mobilis::GeneratorCapture::Comparison.new.compare(baseline, variant)

      expect(comparison.fetch("changed_in_both")).to contain_exactly(
        include("path" => "generated.txt", "baseline" => include("sha256"), "variant" => include("sha256"))
      )
      expect(comparison.to_s).not_to include("content")
    end
  end
end
