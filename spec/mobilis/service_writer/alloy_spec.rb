# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::ServiceWriter::Alloy do
  let(:manifest) { build(:manifest, system: build(:system, :with_otel), suppress_plugins: true) }
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("alloy") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "uses Docker discovery scoped to generated compose projects" do
    expect(writer.config).to include('host             = "unix:///var/run/docker.sock"')
    expect(writer.config).to include('regex         = "generate-(test|development|production)"')
    expect(writer.config).to include('target_label  = "service_name"')
    expect(writer.config).to include('url = "http://loki:3100/loki/api/v1/push"')
  end
end
