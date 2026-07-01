# frozen_string_literal: true

RSpec.describe Mobilis::ServiceWriter::GoAws do
  let(:manifest) { build(:manifest, system: system, suppress_plugins: true) }
  let(:system) do
    Mobilis::System.new("demo").tap do |sys|
      goaws = Mobilis::Node::GoAws.new("eventstream")
      goaws.sns_sqs("capability-changes", ["capability-changes"])
      sys << goaws
    end
  end
  let(:realized_env) { manifest.realized_env(:test) }
  let(:realized_node) { realized_env.find_realized_node_by_name("eventstream") }
  let(:writer) { described_class.new(manifest, realized_env, realized_node) }

  it "renders GoAWS queues and topic subscriptions" do
    local = writer.send(:goaws_yaml).to_serial.fetch("Local")

    expect(local.fetch("Port")).to eq(4100)
    expect(local.fetch("Queues")).to eq([{ "Name" => "capability-changes" }])
    expect(local.fetch("Topics")).to eq(
      [
        {
          "Name" => "capability-changes",
          "Subscriptions" => [
            {
              "QueueName" => "capability-changes",
              "Raw" => false
            }
          ]
        }
      ]
    )
  end
end
