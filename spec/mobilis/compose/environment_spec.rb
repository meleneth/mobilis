RSpec.describe Mobilis::Compose::Environment do
  describe "#to_json" do
    let(:env) { Mobilis::Compose::Environment.new }
    let(:env2) { Mobilis::Compose::Environment.new(base: env) }
    before do
      env.add(Mobilis::Primitives::EmitVar.new("SOME_FOO", nil, 5))
      env.add(Mobilis::Primitives::EmitVar.new("SOME_BAR", nil, 5))
      env2.add(Mobilis::Primitives::EmitVar.new("SOME_BAR", nil, 6))
      env2.add(Mobilis::Primitives::EmitVar.new("SOME_BAZ", nil, 6))
    end
    it "renders" do
      observed = JSON.parse(env.to_json)
      expect(observed).to eq(["SOME_BAR=5", "SOME_FOO=5"])
    end
    it "Allows overrides" do
      observed = JSON.parse(env2.to_json)
      expect(observed).to eq(["SOME_BAR=6", "SOME_BAZ=6", "SOME_FOO=5"])
    end
  end
end
