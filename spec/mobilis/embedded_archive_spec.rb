# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::EmbeddedArchive do
  let(:files) do
    {
      "lib/app.rb" => "puts :hello\n",
      "bin/start" => {content: "#!/bin/sh\nexec ruby lib/app.rb\n", executable: true},
      "assets/logo.bin" => "\x00\xFF\x10".b
    }
  end

  it "packs deterministically with stable ordering and normalized metadata" do
    first = described_class.pack(files:, entrypoint: "bin/start", dependencies: %w[rack json])
    reordered = described_class.pack(files: files.to_a.reverse.to_h, entrypoint: "bin/start", dependencies: %w[json rack])

    expect(first).to eq(reordered)
    bundle = described_class.unpack(first)
    expect(bundle.entries.map(&:path)).to eq(%w[assets/logo.bin bin/start lib/app.rb])
    expect(bundle.entrypoint).to eq("bin/start")
    expect(bundle.dependencies).to eq(%w[json rack])
    expect(bundle.entry("bin/start").executable).to be(true)
    expect(bundle.entry("assets/logo.bin").content).to eq("\x00\xFF\x10".b)
    expect(bundle.entry("assets/logo.bin").content_type).to eq("application/octet-stream")
  end

  it "replaces one member while preserving every unrelated member byte-for-byte" do
    payload = described_class.pack(files:, entrypoint: "bin/start")
    before = described_class.unpack(payload)
    changed_payload = described_class.replace(payload, "lib/app.rb", "puts :changed\n")
    changed = described_class.unpack(changed_payload)

    expect(changed.entry("lib/app.rb").content).to eq("puts :changed\n")
    expect(changed.entry("assets/logo.bin").content).to eq(before.entry("assets/logo.bin").content)
    expect(changed.entry("bin/start").content).to eq(before.entry("bin/start").content)
    expect(described_class.replace(payload, "lib/app.rb", "puts :hello\n")).to eq(payload)
  end

  it "rejects unsafe paths and missing entrypoints" do
    ["../secret", "/absolute", "a/../../b", "a//b", "a\\b", "."].each do |path|
      expect { described_class.pack(files: {path => "bad"}) }.to raise_error(ArgumentError, /Unsafe/)
    end
    expect { described_class.pack(files: {"app.rb" => ""}, entrypoint: "missing.rb") }
      .to raise_error(ArgumentError, /not a member/)
  end

  it "rejects malformed Base64, corrupt headers, and integrity mismatches" do
    expect { described_class.unpack("not base64!") }.to raise_error(ArgumentError)

    payload = described_class.pack(files: {"app.rb" => "safe\n"})
    corrupt_tar = Base64.strict_decode64(payload)
    corrupt_tar.setbyte(0, corrupt_tar.getbyte(0) ^ 1)
    expect { described_class.unpack(Base64.strict_encode64(corrupt_tar)) }
      .to raise_error(ArgumentError, /checksum/)

    manifest_tampered = Base64.strict_decode64(payload)
    content_offset = 512
    marker = manifest_tampered.index(Digest::SHA256.hexdigest("safe\n"), content_offset)
    manifest_tampered.setbyte(marker, marker ? "0".ord : 0)
    header = manifest_tampered.byteslice(0, 512).dup
    header[148, 8] = "        "
    manifest_tampered[148, 8] = format("%06o\0 ", header.bytes.sum)
    expect { described_class.unpack(Base64.strict_encode64(manifest_tampered)) }
      .to raise_error(ArgumentError, /integrity/)
  end

  it "rejects unsupported tar entry types before executing or exposing them" do
    payload = described_class.pack(files: {"app.rb" => "safe\n"})
    tar = Base64.strict_decode64(payload)
    manifest_size = tar.byteslice(124, 12).split("\0", 2).first.to_i(8)
    member_offset = 512 + ((manifest_size + 511) / 512 * 512)
    tar.setbyte(member_offset + 156, "2".ord)
    header = tar.byteslice(member_offset, 512).dup
    header[148, 8] = "        "
    tar[member_offset + 148, 8] = format("%06o\0 ", header.bytes.sum)

    expect { described_class.unpack(Base64.strict_encode64(tar)) }
      .to raise_error(ArgumentError, /Unsupported tar entry type/)
  end

  it "expands through the public node DSL into the existing file generation model" do
    payload = described_class.pack(files: {"config/app.txt" => "generated\n"})
    node = Mobilis::Node::Rack.new("app")

    node.embedded_archive("source", payload:)

    file = node.models.grep(Mobilis::Model::File).fetch(0)
    expect(file.path).to eq("config/app.txt")
    expect(file.content).to eq("generated\n")
  end
end

RSpec.describe Mobilis::Model::File do
  it "round trips binary content through system JSON using Base64" do
    system = Mobilis::System.new("binary")
    node = Mobilis::Node::Rack.new("app")
    node.add_model(described_class.new("asset.bin", "\x00\xFF".b))
    system << node

    loaded = Mobilis::System.from_json(system.to_json)

    expect(loaded.config_nodes.values.fetch(0).models.fetch(0).content).to eq("\x00\xFF".b)
  end
end
