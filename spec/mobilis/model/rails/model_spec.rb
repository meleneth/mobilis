require "spec_helper"

RSpec.describe Mobilis::Model::Rails::Model do
  let(:model) { build(:rails_model, name: "some_model") }
  describe "#to_h" do
    it "serializes" do
      expect(model.to_h).to eq(
        {
          name: "some_model",
          fields: [],
          type: "Mobilis::Model::Rails::Model"
        }
      )
    end
  end
  describe "#string" do
    before :each do
      model.string("name")
    end
    it "adds a field of type string" do
      expect(model.to_h).to eq(
        {
          name: "some_model",
          fields: [{ name: "name", type: "string" }],
          type: "Mobilis::Model::Rails::Model"
        }
      )
    end
    it "round trips" do
      hydrated_model = Mobilis::Model::Rails::Model.from_h(model.to_h)
      expect(hydrated_model.to_h).to eq(
        {
          name: "some_model",
          fields: [{ name: "name", type: "string" }],
          type: "Mobilis::Model::Rails::Model"
        }
      )
    end
  end

  describe "#jsonb" do
    it "adds a PostgreSQL jsonb field" do
      model.jsonb("metadata")

      expect(model.field_args).to eq(["metadata:jsonb"])
      expect(model.to_h).to include(fields: [{ name: "metadata", type: "jsonb" }])
    end
  end

  describe ".from_h" do
    it "raises if type is incorrect" do
      expect do
        described_class.from_h(name: "bad", type: "Wrong::Class", fields: [])
      end.to raise_error(ArgumentError, /Expected type/)
    end
  end

  describe "#filterable" do
    it "marks the model as API-exposed and serializes filter fields" do
      model.filterable(:id, :account_id)

      expect(model.to_h).to include(
        api_exposed: true,
        filterable_fields: ["id", "account_id"]
      )
    end

    it "round trips exposed resource metadata" do
      model.filterable(:id)

      hydrated_model = described_class.from_h(model.to_h)

      expect(hydrated_model).to be_api_exposed
      expect(hydrated_model.filterable_fields).to eq(["id"])
    end
  end

  describe "#existing!" do
    it "marks a model as metadata-only for generators and round trips through JSON" do
      model = described_class.new("user")
      model.existing!

      hydrated_model = described_class.from_h(JSON.parse(model.to_h.to_json, symbolize_names: true))

      expect(model).not_to be_generate_model
      expect(hydrated_model).not_to be_generate_model
    end
  end
end
