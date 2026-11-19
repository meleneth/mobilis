# frozen_string_literal: true

require "spec_helper"
require "json"
require "mobilis/generator_compatibility"
require "tmpdir"

RSpec.describe Mobilis::GeneratorCompatibility do
  let(:capture_path) do
    File.expand_path("../../generator_compatibility/captures/rspec-install/default.json", __dir__)
  end
  let(:capture) { JSON.parse(File.read(capture_path)) }
  let(:registry) do
    Mobilis::GeneratorCompatibility::Registry.new.tap do |value|
      value.register(
        generator: "rspec:install",
        version: "8.1.0",
        arguments: [],
        transformation: Mobilis::GeneratorCompatibility::CapturedFileCreation.new(
          capture,
          required_paths: ["config/application.rb", "config/environment.rb"]
        )
      )
    end
  end

  it "applies the evidence-backed file creation and is idempotent for identical files" do
    Dir.mktmpdir("compatibility-workspace") do |directory|
      workspace = Mobilis::GeneratorCompatibility::DirectoryWorkspace.new(directory)
      workspace.write("config/application.rb", "class Application; end\n")
      workspace.write("config/environment.rb", "require_relative \"application\"\n")

      first = registry.apply(generator: "rspec:install", version: "8.1.0", arguments: [], workspace:)
      second = registry.apply(generator: "rspec:install", version: "8.1.0", arguments: [], workspace:)

      expect(first.fetch(:created)).to contain_exactly(".rspec", "spec/rails_helper.rb", "spec/spec_helper.rb")
      expect(second.fetch(:unchanged)).to contain_exactly(".rspec", "spec/rails_helper.rb", "spec/spec_helper.rb")
    end
  end

  it "rejects unsupported arguments explicitly" do
    Dir.mktmpdir("compatibility-workspace") do |directory|
      workspace = Mobilis::GeneratorCompatibility::DirectoryWorkspace.new(directory)
      workspace.write("config/application.rb", "class Application; end\n")
      workspace.write("config/environment.rb", "require_relative \"application\"\n")

      expect do
        registry.apply(
          generator: "rspec:install",
          version: "8.1.0",
          arguments: ["--default-path", "test/specs"],
          workspace:
        )
      end.to raise_error(Mobilis::GeneratorCompatibility::UnsupportedInvocationError)
    end
  end

  it "detects conflicts before writing any captured files" do
    Dir.mktmpdir("compatibility-workspace") do |directory|
      workspace = Mobilis::GeneratorCompatibility::DirectoryWorkspace.new(directory)
      workspace.write("config/application.rb", "class Application; end\n")
      workspace.write("config/environment.rb", "require_relative \"application\"\n")
      workspace.write("spec/rails_helper.rb", "user change")

      expect do
        registry.apply(generator: "rspec:install", version: "8.1.0", arguments: [], workspace:)
      end.to raise_error(Mobilis::GeneratorCompatibility::WorkspaceConflictError, /rails_helper/)
      expect(workspace.exist?(".rspec")).to be(false)
    end
  end

  it "rejects path traversal and symlink escapes" do
    Dir.mktmpdir("compatibility-workspace") do |directory|
      outside = Dir.mktmpdir("compatibility-outside")
      workspace = Mobilis::GeneratorCompatibility::DirectoryWorkspace.new(directory)
      File.symlink(outside, File.join(directory, "escape"))

      expect { workspace.write("../outside", "bad") }
        .to raise_error(Mobilis::GeneratorCompatibility::UnsafePathError)
      expect { workspace.write("escape/file", "bad") }
        .to raise_error(Mobilis::GeneratorCompatibility::UnsafePathError)
    ensure
      FileUtils.remove_entry(outside) if outside && Dir.exist?(outside)
    end
  end
end
