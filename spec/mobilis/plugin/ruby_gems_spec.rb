# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Plugin::RubyGems do
  it "adds one shared local gem to each Rails consumer from the generated project root" do
    accounts = build(:rails_node, name: "accounts")
    shared_gem = accounts.local_gem("shared-library", require_name: "shared/library")
    billing = build(:rails_node, name: "billing")
    billing.use_local_gem(shared_gem)
    manifest = build(:manifest, system: build(:system, nodes: [accounts, billing]))
    plugin = described_class.new(manifest)
    builder = instance_double(Mobilis::Plugin::RailsBuilder)

    allow(plugin).to receive(:rails_builder).and_return(builder)
    allow(plugin).to receive(:commit_all)
    expect(builder).to receive(:container_run_for).with(
      kind_of(Mobilis::Realized::Rails),
      "bundle add shared-library --path ../localgems/shared-library --require shared/library"
    )
    expect(builder).to receive(:container_run_for).with(
      kind_of(Mobilis::Realized::Rails),
      "bundle add shared-library --path ../localgems/shared-library --require shared/library"
    )

    plugin.hook_after_services_written
  end
end
