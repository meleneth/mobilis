require "spec_helper"

RSpec.describe Mobilis::Model::Script do
  let(:config_node) { build(:rails_node) }
  describe "#add_script" do
    it "Adds a script model to the object" do
      config_node.add_script("some_script.sh", "some_script_contents")
      expect(config_node.models[0].class).to eq(Mobilis::Model::Script)
    end
  end
end
