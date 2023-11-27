# frozen_string_literal: true

RSpec.describe Mobilis::Project do
  let(:metaproject) { build(:metaproject) }
  it "factory works" do
    expect(metaproject.instance_of?(Mobilis::Project)).to be_truthy
  end
  it "Allows add of rails project" do
    metaproject.add_prime_stack_rails_project("my_prime")
    data = metaproject.instance_variable_get(:@data)
    expect(data[:projects][0][:name]).to eq("my_prime")
  end
end

RSpec.describe Mobilis::RailsProject do
  let(:rails_project) { build(:rails_prime, name: "my_prime") }
  it "factory works" do
    expect(rails_project.instance_of?(Mobilis::RailsProject)).to be_truthy
    expect(rails_project.name).to eq("my_prime")
  end
  it "belongs to it's metaproject" do
    expect(rails_project.metaproject.instance_variable_get(:@data)[:projects][0][:name]).to eq("my_prime")
  end
end
