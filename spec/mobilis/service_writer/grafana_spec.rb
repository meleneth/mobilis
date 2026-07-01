# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::ServiceWriter::Grafana do
  let(:manifest) { build(:manifest, system: build(:system, :with_otel), suppress_plugins: true) }
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("grafana") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "adds a Loki datasource when Loki is present" do
    datasources = writer.datasources.to_serial.fetch("datasources")
    expect(datasources).to include(
      {
        "name" => "Loki",
        "type" => "loki",
        "uid" => "loki_ds",
        "access" => "proxy",
        "url" => "http://loki:3100",
        "isDefault" => false
      }
    )
  end
end
