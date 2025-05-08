RSpec.describe Mobilis::Compose::Environment do
  describe "#to_json" do
    let(:env) { Mobilis::Compose::Environment.new }
    let(:env2) { Mobilis::Compose::Environment.new(base: env) }
    before do
      env.add(Mobilis::Primitives::EmitVar.new("SOME_FOO", nil, 5))
      env.add(Mobilis::Primitives::EmitVar.new("SOME_BAR", nil, 5))
      env2.add(Mobilis::Primitives::EmitVar.new("SOME_BAR", nil, 6))
      env2.add(Mobilis::Primitives::EmitVar.new("SOME_BAZ", nil, 6))
      env2.add(Mobilis::Primitives::EmitVar.new("SOME_ALIASED_VAR", "SERVICE_SPECIFIC_ALIASED_VAR", 7, aliased: true))
      env2.add(Mobilis::Primitives::EmitVar.new(nil, "ONLY_ENVFILE_VAR", 8))
      env2.add(Mobilis::Primitives::EmitVar.new("PORT", nil, 8080, do_not_resolve: true))
    end
    it "renders" do
      observed = JSON.parse(env.to_json)
      expect(observed).to eq(["SOME_BAR=5", "SOME_FOO=5"])
    end
    it "Allows overrides" do
      observed = JSON.parse(env2.to_json)
      expect(observed).to eq([
                               "SOME_ALIASED_VAR=${SERVICE_SPECIFIC_ALIASED_VAR}",
                               "SOME_BAR=6",
                               "SOME_BAZ=6",
                               "SOME_FOO=5"
                             ])
    end
    it "Knows what an envfile-only var looks like, and includes aliased vars" do
      expect(env2.envfile_vars.map(&:env_repr)).to eq(["SERVICE_SPECIFIC_ALIASED_VAR=7", "ONLY_ENVFILE_VAR=8"])
    end
  end
end
