# frozen_string_literal: true

require "bundler"
require "json"
require "mobilis/generator_capture"

repository = File.expand_path("..", __dir__)
fixture = File.join(__dir__, "fixtures", "minimal_rails_application")
output = ENV.fetch("MOBILIS_CAPTURE_OUTPUT", File.join(__dir__, "captures", "rspec-install"))
runner = Mobilis::GeneratorCapture::Runner.new
rspec_rails = Bundler.load.specs.find { |specification| specification.name == "rspec-rails" }
raise "rspec-rails is not present in the compatibility bundle" unless rspec_rails

definition = lambda do |name, arguments|
  Mobilis::GeneratorCapture.define(name) do
    repository path: repository
    generator "rspec:install", version: rspec_rails.version.to_s
    fixture "minimal_rails_application", path: fixture
    command "ruby", "{repository}/generator_compatibility/run_rspec_install.rb", "{workspace}"
    arguments(*arguments)
    environment "BUNDLE_GEMFILE" => "{repository}/generator_compatibility/Gemfile"
    runtime(
      "ruby_engine" => RUBY_ENGINE,
      "ruby_version" => RUBY_VERSION,
      "railties_version" => Bundler.load.specs.find { |specification| specification.name == "railties" }.version.to_s,
      "rspec_rails_version" => rspec_rails.version.to_s
    )
  end
end

baseline = runner.run(definition.call("rspec-install-default", []))
variant = runner.run(definition.call("rspec-install-default-path", ["--default-path", "test/specs"]))

runner.write(baseline, File.join(output, "default.json"))
runner.write(variant, File.join(output, "default-path.json"))
runner.write(
  Mobilis::GeneratorCapture::Comparison.new.compare(baseline, variant),
  File.join(output, "default-path-comparison.json")
)

failed = [baseline, variant].reject { |capture| capture.dig("result", "success") }
abort "Generator captures failed: #{failed.map { |capture| capture.fetch("capture") }.join(", ")}" if failed.any?
