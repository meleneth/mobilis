# frozen_string_literal: true

RSpec.describe "Rails Field" do
  let(:field) { build(:rails_field, name: "name", type: Mobilis::RAILS_MODEL_TYPE_STRING) }
  let(:num_things_field) { build(:rails_field, name: "num_things", type: Mobilis::RAILS_MODEL_TYPE_INTEGER) }
  let(:comments_field) { build(:rails_field, name: "comment", type: Mobilis::RAILS_MODEL_TYPE_REFERENCE) }

  it "#for_line" do
    expect(field.for_line).to eq("name:string")
  end

  describe "#to_h" do
    it "handles simple case" do
      expect(field.to_h).to eq({name: "name", type: :string})
    end
  end

  describe "#to_graphql" do
    it "works for strings" do
      expect(field.to_graphql).to eq "name:String"
    end
    it "works for int" do
      expect(num_things_field.to_graphql).to eq "num_things:Int"
    end
    it "works for references" do
      expect(comments_field.to_graphql).to eq "comments:[Comment]"
    end
  end
end
