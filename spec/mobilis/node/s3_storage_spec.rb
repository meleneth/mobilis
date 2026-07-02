# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Node::S3Storage do
  it "tracks unique bucket names" do
    node = described_class.new("assets")
    node.bucket("uploads")
    node.bucket("uploads")
    node.bucket(:exports)

    expect(node.buckets).to eq(["uploads", "exports"])
    expect(node.default_bucket).to eq("uploads")
  end

  it "serializes buckets" do
    node = described_class.new("assets", buckets: ["uploads"])

    expect(node.to_h).to include(buckets: ["uploads"])
  end
end
