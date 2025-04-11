# frozen_string_literal: true

RSpec.describe JobesWar::Node::Value do
  let(:value_node) { JobesWar::Node::Value.new("war") }

  it "#width" do
    expect(value_node.calculated_width).to eq(3)
  end
end
