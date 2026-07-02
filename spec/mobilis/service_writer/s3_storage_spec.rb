# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::ServiceWriter::S3Storage do
  let(:manifest) { build(:manifest, system: build(:system, :with_s3_storage), suppress_plugins: true) }
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("assets") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "writes an entrypoint that starts SeaweedFS and creates configured buckets" do
    expect(writer.entrypoint).to include("weed server \\")
    expect(writer.entrypoint).to include("-s3.port=8333")
    expect(writer.entrypoint).to include("s3.bucket.list")
    expect(writer.entrypoint).to include("s3.bucket.create -name uploads")
    expect(writer.entrypoint).to include("s3.bucket.create -name exports")
  end

  it "only enables SeaweedFS metrics when the storage node is wired to observability" do
    expect(writer.entrypoint).not_to include("-metricsPort=9327")

    manifest = build(:manifest, system: build(:system, :with_observable_s3_storage), suppress_plugins: true)
    realized_env = manifest.realized_env(:test)
    realized_node = realized_env.find_realized_node_by_name("assets")
    writer = described_class.new(manifest, realized_env, realized_node)

    expect(writer.entrypoint).to include("-metricsPort=9327")
  end

  it "writes an executable entrypoint" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        writer.write

        expect(File).to exist("entrypoint.sh")
        expect(File.read("entrypoint.sh")).to include("weed shell -master=localhost:9333 -filer=localhost:8888")
      end
    end
  end
end
