require "spec_helper"

RSpec.describe Mobilis::Model::Rails::Field do
  describe "#to_h" do
    it "serializes" do
      model = build(:rails_field, name: "name", type: "string")

      expect(model.to_h).to eq({ name: "name", type: "string" })
    end
    it "deserializes" do
      model = build(:rails_field, name: "name", type: "string")
      deserialized = Mobilis::Model::Rails::Field.from_h(model.to_h)
      expect(deserialized.name).to eq("name")
      expect(deserialized.type).to eq("string")
    end
  end
end
