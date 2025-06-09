RSpec.describe Mobilis::Node::Rails do
  let(:rails_node) { build(:rails_node, id: "27b11f5e-0df1-49b9-8892-230d167233de") }

  describe "With a database" do
    let(:rails_node) { build(:rails_node, :with_postgres) }
    it "uses PostgreSQL when configured" do
      expect(rails_node.primary_database).to be_a(Mobilis::Node::PostgreSQL)
    end
  end

  it "can to_json" do
    expect(rails_node.to_h).to eq(
      {
        id: "27b11f5e-0df1-49b9-8892-230d167233de",
        name: "rails",
        type: "Mobilis::Node::Rails",
        extra_depends_on: [],
        models: []
      }
    )
  end

  describe "Supports Models" do
    before :each do
      rails_node.add_rails_model("user") do
        string "name"
      end
    end
    it "can add models" do
    end
    it "to_h exports models" do
      expect(rails_node.to_h).to eq(
        {
          id: "27b11f5e-0df1-49b9-8892-230d167233de",
          name: "rails",
          type: "Mobilis::Node::Rails",
          extra_depends_on: [],
          models: [
            {
              type: "Mobilis::Model::Rails::Model",
              name: "user",
              fields: [{ name: "name", type: "string" }]
            }
          ]
        }
      )
    end
  end
end
