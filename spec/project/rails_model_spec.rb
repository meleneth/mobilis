# frozen_string_literal: true

RSpec.describe "Rails Model" do
  let(:model) { build(:rails_model, name: "SomeModel") }

  it "#line" do
    expect(model.line).to eq("./bin/rails g scaffold SomeModel ")
  end

  describe "#to_h" do
    it "handles simple case" do
      expect(model.to_h).to eq({name: "SomeModel", fields: [], indexes: []})
    end
  end

  describe "#add_field" do
    let(:expected) { {name: "SomeModel", fields: [ {name: "some_field", type: :string}], indexes: []} }
    it "handles simple case" do
      model.add_field(name: "some_field", type: Mobilis::RAILS_MODEL_TYPE_STRING.name)
      expect(model.to_h).to eq(expected)
    end
  end

  describe "#add_references" do
    let(:author_model) { build(:rails_model, name: "Author") }
    let(:post_model) { build(:rails_model, name: "Post") }
    let(:expected) { {name: "Author", fields: [{name: "post", type: :references}], indexes: []} }

    it "handles simple case" do
      author_model.add_references(post_model)
      expect(author_model.to_h).to eq(expected)
    end
  end

  describe "#add_index" do
    let(:author_model) { build(:rails_model, name: "Author") }
    it "handles simple case" do
      author_model.add_field(name: "name", type: Mobilis::RAILS_MODEL_TYPE_STRING.name)
      author_model.add_field(name: "email", type: Mobilis::RAILS_MODEL_TYPE_STRING.name)
      author_model.add_index("name")
      author_model.add_index("name", "email")
      expect(author_model.to_h[:indexes]).to eq [["name"], ["name", "email"]]
    end
  end
end
