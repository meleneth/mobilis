# frozen_string_literal: true

require "spec_helper"
require "mobilis/file_lines"
require "tempfile"

RSpec.describe Mobilis::FileLines do
  let(:tempfile) do
    Tempfile.new("file_lines_test").tap do |f|
      f.write("line one\nline two\nline three\n")
      f.rewind
    end
  end

  after { tempfile.unlink }

  it "loads lines from file" do
    fl = described_class.from(tempfile.path)
    expect(fl.lines).to eq(
      [
        "line one",
        "line two",
        "line three"
      ]
    )
  end

  it "can insert_after" do
    fl = described_class.from(tempfile.path)
    fl.insert_after(/line two/, "inserted line")
    expect(fl.lines).to eq(
      [
        "line one",
        "line two",
        "inserted line",
        "line three"
      ]
    )
  end

  it "can insert_before" do
    fl = described_class.from(tempfile.path)
    fl.insert_before(/line two/, "before line")
    expect(fl.lines).to eq(
      [
        "line one",
        "before line",
        "line two",
        "line three"
      ]
    )
  end

  it "can replace_line with block" do
    fl = described_class.from(tempfile.path)
    fl.replace_line(/line two/) { |l| l.upcase }
    expect(fl.lines[1]).to eq("LINE TWO")
  end

  it "can gsub_lines" do
    fl = described_class.from(tempfile.path)
    fl.gsub_lines(/line/, "row")
    expect(fl.lines).to include("row one", "row two", "row three")
  end

  it "can delete lines by condition" do
    fl = described_class.from(tempfile.path)
    fl.delete_if { |l| l.include?("two") }
    expect(fl.lines).to eq(
      [
        "line one",
        "line three"
      ]
    )
  end

  it "saves to the original file" do
    fl = described_class.from(tempfile.path)
    fl.insert_after(/line two/, "extra line").save
    contents = File.read(tempfile.path)
    expect(contents).to include("extra line")
  end

  it "adds a block comment aligned to a line match" do
    path = Tempfile.new("block_comment_test").tap do |f|
      f.write("gem 'rails'\ngem 'pg'\n")
      f.rewind
    end

    Mobilis::FileLines.edit(path.path) do
      block_comment(/rails/,
                    [
                      "this line",
                      "and another"
                    ])
    end

    contents = File.read(path.path)
    expect(contents).to eq("gem 'rails' # this line\n             # and another\ngem 'pg'\n")
  end
end
