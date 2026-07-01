require "spec_helper"

RSpec.describe Mobilis::Model::Script do
  let(:config_node) { build(:rails_node) }
  describe "#add_script" do
    it "Adds a script model to the object" do
      config_node.add_script("some_script.sh", "some_script_contents")
      expect(config_node.models[0].class).to eq(Mobilis::Model::Script)
    end
  end

  describe "#add_gem" do
    it "adds a RubyGem model to the object" do
      config_node.add_gem("retroui-rails", git: "https://github.com/meleneth/retroui-rails.git")

      expect(config_node.models[0]).to be_a(Mobilis::Model::RubyGem)
      expect(config_node.models[0].bundle_add_args).to eq([
                                                            "retroui-rails",
                                                            "--git",
                                                            "https://github.com/meleneth/retroui-rails.git"
                                                          ])
    end
  end
end
