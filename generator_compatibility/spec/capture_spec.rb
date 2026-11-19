# frozen_string_literal: true

require "json"
require "open3"
require "tmpdir"

RSpec.describe "rspec:install compatibility corpus" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:capture_root) { File.join(root, "captures", "rspec-install") }

  it "reproduces baseline and argument-variation captures from clean fixtures" do
    Dir.mktmpdir("mobilis-rspec-capture") do |output|
      stdout, stderr, status = Open3.capture3(
        {"MOBILIS_CAPTURE_OUTPUT" => output},
        File.join(root, "bin", "capture-rspec-install"),
        chdir: root
      )
      expect(status).to be_success, "#{stdout}\n#{stderr}"

      %w[default.json default-path.json default-path-comparison.json].each do |filename|
        expected = JSON.parse(File.read(File.join(capture_root, filename)))
        actual = JSON.parse(File.read(File.join(output, filename)))
        expect(actual).to eq(expected), "capture changed: #{filename}"
      end
    end
  end

  it "uses the identical fixture baseline for every argument variation" do
    baseline = JSON.parse(File.read(File.join(capture_root, "default.json")))
    variant = JSON.parse(File.read(File.join(capture_root, "default-path.json")))

    expect(variant.fetch("fixture")).to eq(baseline.fetch("fixture"))
    expect(baseline.dig("invocation", "arguments")).to eq([])
    expect(variant.dig("invocation", "arguments")).to eq(["--default-path", "test/specs"])
  end
end
