# frozen_string_literal: true

RSpec.describe Mobilis::Manifest do
  subject(:manifest) { build(:manifest, :with_rails_and_postgres, :suppress_plugins) }

  describe "#realized_env" do
    it "finds the correct realized env..." do
      realized_env = manifest.realized_env(:test)
      expect(realized_env.to_s).to eq("test")
    end
    it "... which has a rails realized node" do
      realized_env = manifest.realized_env(:test)
      rails_realized_node = realized_env.node_by_name("user")
    end
  end
end
