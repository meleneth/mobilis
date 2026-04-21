RSpec.describe Mobilis::Node::Rails do
  let(:rails_node) { build(:rails_node, id: "27b11f5e-0df1-49b9-8892-230d167233de") }

  describe "#use_api!" do
    it "sets api_mode?" do
      rails_node.use_api!
      expect(rails_node.api_mode?).to eq(true)
    end
    it "conflicts with #use_haml!" do
      rails_node.use_haml!
      expect { rails_node.use_api! }.to raise_error(RuntimeError, /Cannot enable API mode/)
    end
    it "changes #rails_new_command" do
      rails_node.use_api!
      expect(rails_node.rails_new_command).to eq("rails new rails . --api")
    end
  end

  describe "#use_haml!" do
    it "sets haml_enabled?" do
      rails_node.use_haml!
      expect(rails_node.haml_enabled?).to eq(true)
    end
  end

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
        api_mode: nil,
        extra_depends_on: [],
        models: [],
        rspec_enabled: nil,
        factory_bot_enabled: nil,
        haml_enabled: nil,
        tailwind_enabled: nil,
        uuid_primary_keys: nil
      }
    )
  end

  describe "extra_depends_on" do
    let(:account_rails_node) { build(:rails_node, name: "account") }
    before :each do
      rails_node.has_extra_depends_on(account_rails_node)
    end
    it "stores target" do
      expect(rails_node.extra_depends_on[0][:target].name).to eq("account")
    end
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
          api_mode: nil,
          name: "rails",
          type: "Mobilis::Node::Rails",
          extra_depends_on: [],
          models: [
            {
              type: "Mobilis::Model::Rails::Model",
              name: "user",
              fields: [{ name: "name", type: "string" }]
            }
          ],
          rspec_enabled: nil,
          factory_bot_enabled: nil,
          haml_enabled: nil,
          tailwind_enabled: nil,
          uuid_primary_keys: nil
        }
      )
    end
  end
end
