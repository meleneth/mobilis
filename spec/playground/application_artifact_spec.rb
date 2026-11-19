# frozen_string_literal: true

require "base64"
require "fileutils"
require "rubygems/package"
require "stringio"
require "tmpdir"
require_relative "../../playground/scripts/application_artifact"

RSpec.describe MobilisPlayground::ApplicationArtifact do
  def build(root)
    described_class.build(
      root:,
      runtime_package: "@ruby/4.0-wasm-wasi",
      runtime_version: "2.10.1",
      load_paths: ["/src/lib", "/src/app"],
      boot_feature: "boot"
    )
  end

  it "builds a deterministic content-addressed ustar application with per-file integrity" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p([File.join(root, "src/lib"), File.join(root, "src/app")])
      File.binwrite(File.join(root, "src/lib/mobilis.rb"), "module Mobilis\nend\n")
      File.binwrite(File.join(root, "src/app/boot.rb"), "require \"mobilis\"\n")

      first = build(root)
      File.utime(Time.now + 60, Time.now + 60, File.join(root, "src/lib/mobilis.rb"))
      second = build(root)

      expect(second.archive).to eq(first.archive)
      expect(second.manifest).to eq(first.manifest)
      expect(first.manifest).to include(
        format: "mobilis-browser-application",
        version: 1,
        application_version: Digest::SHA256.hexdigest(first.archive),
        compatible_runtime: {package: "@ruby/4.0-wasm-wasi", package_version: "2.10.1"}
      )
      expect(first.manifest.fetch(:artifact)).to include(
        size: first.archive.bytesize,
        sha256: Digest::SHA256.hexdigest(first.archive),
        integrity: "sha256-#{Base64.strict_encode64(Digest::SHA256.digest(first.archive))}"
      )
      expect(first.manifest.dig(:filesystem, :files).map { |file| file.fetch(:path) })
        .to eq(["src/app/boot.rb", "src/lib/mobilis.rb"])

      contents = Gem::Package::TarReader.new(StringIO.new(first.archive)).to_h do |entry|
        [entry.full_name, entry.read]
      end
      expect(contents).to eq(
        "src/app/boot.rb" => "require \"mobilis\"\n",
        "src/lib/mobilis.rb" => "module Mobilis\nend\n"
      )
    end
  end

  it "changes only the application identity when ordinary Ruby source changes" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p([File.join(root, "src/lib"), File.join(root, "src/app")])
      source = File.join(root, "src/lib/mobilis.rb")
      File.write(source, "module Mobilis; VERSION = 1; end\n")
      File.write(File.join(root, "src/app/boot.rb"), "require \"mobilis\"\n")
      first = build(root)
      File.write(source, "module Mobilis; VERSION = 2; end\n")
      second = build(root)

      expect(second.manifest.fetch(:application_version)).not_to eq(first.manifest.fetch(:application_version))
      expect(second.manifest.fetch(:compatible_runtime)).to eq(first.manifest.fetch(:compatible_runtime))
    end
  end

  it "rejects symlinks instead of following files outside the application tree" do
    Dir.mktmpdir do |root|
      Dir.mktmpdir do |outside|
        FileUtils.mkdir_p([File.join(root, "src/lib"), File.join(root, "src/app")])
        File.write(File.join(root, "src/app/boot.rb"), "# boot\n")
        File.write(File.join(outside, "secret"), "nope")
        File.symlink(File.join(outside, "secret"), File.join(root, "src/lib/secret"))

        expect { build(root) }.to raise_error(ArgumentError, /only supports regular files/)
      end
    end
  end

  it "requires every declared Ruby load path to exist in the artifact" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "src/lib"))
      File.write(File.join(root, "src/lib/mobilis.rb"), "# source\n")

      expect { build(root) }.to raise_error(ArgumentError, /load path does not exist: \/src\/app/)
    end
  end
end
