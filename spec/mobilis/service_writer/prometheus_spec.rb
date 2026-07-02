# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::ServiceWriter::Prometheus do
  let(:manifest) { build(:manifest, system: build(:system, :with_observable_s3_storage), suppress_plugins: true) }
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("prometheus") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "scrapes SeaweedFS metrics for generated S3 storage nodes" do
    scrape_configs = writer.datasources.to_serial.fetch("scrape_configs")

    expect(scrape_configs).to include(
      hash_including(
        "job_name" => "assets_seaweedfs",
        "static_configs" => [
          {
            "targets" => ["assets:9327"]
          }
        ]
      )
    )
  end

  it "does not scrape S3 storage nodes that are not wired to observability" do
    manifest = build(
      :manifest,
      system: build(:system, :with_otel, :with_s3_storage),
      suppress_plugins: true
    )
    realized_env = manifest.realized_env(:test)
    realized_node = realized_env.find_realized_node_by_name("prometheus")
    writer = described_class.new(manifest, realized_env, realized_node)

    scrape_configs = writer.datasources.to_serial.fetch("scrape_configs")
    expect(scrape_configs).not_to include(hash_including("job_name" => "assets_seaweedfs"))
  end
end
