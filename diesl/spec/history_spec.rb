# frozen_string_literal: true

require "diesl"

RSpec.describe Diesl::History do
  it "replays structured edits and rejects stale undo" do
    history = described_class.new
    history.record("before", "after", label: "rename")
    expect { history.undo("changed elsewhere") }.to raise_error(Diesl::Conflict)
    expect(history.undo("after")).to eq("before")
    expect(history.redo("before")).to eq("after")
  end

  it "clears redo on a new edit" do
    history = described_class.new
    history.record("a", "b", label: "first")
    history.undo("b")
    history.record("a", "c", label: "second")
    expect { history.redo("c") }.to raise_error(Diesl::Conflict)
  end
end
