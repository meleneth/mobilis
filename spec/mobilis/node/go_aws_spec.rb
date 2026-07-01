# frozen_string_literal: true

RSpec.describe Mobilis::Node::GoAws do
  it "builds SNS to SQS topology and round trips through system JSON" do
    node = described_class.new("eventstream")
    node.sns_sqs("capability-changes", ["capability-changes"])

    system = Mobilis::System.new("demo")
    system << node

    restored = Mobilis::System.from_json(system.to_json)
    restored_node = restored.each_config_node.first

    expect(restored_node.queues).to eq(["capability-changes"])
    expect(restored_node.topics).to eq(["capability-changes"])
    expect(restored_node.subscriptions).to eq([{ topic: "capability-changes", queue: "capability-changes" }])
  end
end
