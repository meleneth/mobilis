# frozen_string_literal: true

RSpec.describe "Rails Field" do
  let(:field) { build(:rails_field, name: "name", type: :string) }

  it "#for_line" do
    expect(field.for_line).to eq("name:string")
  end

  describe "#to_h" do
    it "handles simple case" do
      expect(field.to_h).to eq({name: "name", type: :string})
    end
  end
end
