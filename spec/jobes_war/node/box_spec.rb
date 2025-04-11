# frozen_string_literal: true

RSpec.describe JobesWar::Node::Value do
  let(:box_node) { JobesWar::Node::Box.new }

  it "#calculated_width" do
    expect(box_node.calculated_width).to eq(4)
  end
end
