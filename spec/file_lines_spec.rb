# frozen_string_literal: true

RSpec.describe Mobilis::FileLines do
  let(:subject_name) { "some_name.txt" }
  let(:subject_lines) { [] }
  let(:subject) { Mobilis::FileLines.new filename: subject_name, lines: subject_lines }

  describe "basic functionality" do
    it "has lines" do
      expect(subject.lines).to eq([])
    end
  end

  describe "can have lines" do
    let(:subject_lines) { ['gem "some_gem"', 'gem "rails"'] }
    it "has lines" do
      expect(subject.lines).to eq(['gem "some_gem"', 'gem "rails"'])
    end
    describe "#match" do
      it "true case" do
        expect(subject.match "some_gem").to be_truthy
        expect(subject.match "rails").to be_truthy
      end
      it "false case" do
        expect(subject.match "other_gem").to eq([])
        expect(subject.match "machina").to eq([])
      end
    end
    it "#index_of" do
      expect(subject.index_of(/gem "rails"/)).to eq 1
    end
    it "#insert_line_at" do
      subject.insert_line_at('gem "something"', 1)
      expect(subject.lines).to eq(['gem "some_gem"', 'gem "something"', 'gem "rails"'])
    end
  end
end
