# frozen_string_literal: true

RSpec.describe JobesWar::Node::TicTac do
  let(:tic_tac) { JobesWar::Node::TicTac.new }
  let(:war) { JobesWar::Node::Value.new("war") }
  let(:peace) { JobesWar::Node::Value.new("peace") }
  let(:love) { JobesWar::Node::Value.new("love") }
  let(:passion) { JobesWar::Node::Value.new("passion") }

  it "#calculated_width" do
    tic_tac << [war, peace]
    tic_tac << [love, passion]

    expect(tic_tac.calculated_width).to eq(14)
  end

  it "#render" do
    tic_tac << [war, peace]
    tic_tac << [love, passion]
    lines = tic_tac.each_line
    expect(lines.to_a).to eq(
      ["war  | peace  ",
       "love | passion"]
    )
  end

  it "#column_max_widths" do
    tic_tac << [war, peace]
    tic_tac << [love, passion]
    maxes = tic_tac.column_max_widths
    expect(maxes).to eq([4, 7])
  end
end
