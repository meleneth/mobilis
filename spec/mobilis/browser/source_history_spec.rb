# frozen_string_literal: true

RSpec.describe Mobilis::Browser::SourceHistory do
  subject(:history) { described_class.new }

  it "undoes and redoes an atomic source edit" do
    history.record("before", "after", label: "embedded document edit")

    expect(history.undo?).to be(true)
    expect(history.undo_label).to eq("embedded document edit")
    expect(history.undo("after")).to eq("before")
    expect(history.redo("before")).to eq("after")
  end

  it "refuses to overwrite source changed outside the recorded transaction" do
    history.record("before", "after", label: "structured edit")

    expect { history.undo("newer") }.to raise_error(ArgumentError, /refusing to overwrite/)
    expect(history.undo?).to be(true)
  end

  it "clears redo entries after a new branch and resets manual-edit history" do
    history.record("one", "two", label: "first")
    history.undo("two")
    history.record("one", "three", label: "second")

    expect(history.redo?).to be(false)
    history.reset
    expect(history.undo?).to be(false)
  end
end
