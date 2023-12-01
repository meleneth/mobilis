# frozen_string_literal: true

RSpec.describe Mobilis::Project do
  let(:metaproject) { build(:metaproject) }
  it "factory works" do
    expect(metaproject.instance_of?(Mobilis::Project)).to be_truthy
  end
  it "Allows add of rails project" do
    metaproject.add_prime_stack_rails_project("my_prime")
    expect(metaproject.projects[0].name).to eq("my_prime")
  end
  describe "#to_json" do
    let(:rails_project) { build(:rails_prime, name: "my_prime") }
    it "works for simple metaproject case" do
      expected = { projects: [], username: "meleneth", starting_port_no: 10000, port_gap: 100, name: "meta_project" }
      expect(metaproject.to_json).to eq( expected)
    end
    it "works for simple rails project case" do
      expected = { name: "my_prime", type: :rails, controllers: [], models: [], options: [:rspec, :api, :simplecov, :standard, :factorybot], attributes: {}, links: [] }
      expect(rails_project.to_json).to eq( expected)
    end
    it "works for more complicated case" do
      expected = { projects: [{ name: "my_prime", type: :rails, controllers: [], models: [], options: [:rspec, :api, :simplecov, :standard, :factorybot], attributes: {}, links: [] }], username: "meleneth", starting_port_no: 10000, port_gap: 100, name: "meta_project" }
      expect(rails_project.metaproject.to_json).to eq(expected)
    end
  end
end

RSpec.describe Mobilis::RailsProject do
  let(:rails_project) { build(:rails_prime, name: "my_prime") }
  it "factory works" do
    expect(rails_project.instance_of?(Mobilis::RailsProject)).to be_truthy
    expect(rails_project.name).to eq("my_prime")
  end
  it "belongs to it's metaproject" do
    expect(rails_project.metaproject.projects[0].name).to eq("my_prime")
  end
end
