# frozen_string_literal: true

RSpec.describe "Rails Model" do
  let(:model) { build(:rails_model, name: "SomeModel") }

  it "#line" do
    expect(model.line).to eq("rails g scaffold SomeModel ")
  end

  describe "#to_json" do
    it "handles simple case" do
      expect(model.to_json).to eq({name: "SomeModel", fields: []})
    end
  end

  describe "#add_field" do
    let(:expected) { {name: "SomeModel", fields: [ {name: "some_field", type: :string}]} }
    it "handles simple case" do
      model.add_field(name: "some_field", type: Mobilis::RAILS_MODEL_TYPE_STRING)
      expect(model.to_json).to eq(expected)
    end
  end
end