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
    allow(plugin.directory_service).to receive(:chdir_generate)

    expect(builder).to receive(:container_run).with(
      "bundle add shared-library --path ../localgems/shared-library --require shared/library",
      workdir: "accounts"
    )
    expect(builder).to receive(:container_run).with(
      "bundle add shared-library --path ../localgems/shared-library --require shared/library",
      workdir: "billing"
    )

    plugin.hook_after_services_written
  end
end
