# frozen_string_literal: true

RSpec.describe Mobilis::Project do
  let(:metaproject) { build(:metaproject) }
  it "factory works" do
    expect(metaproject.instance_of?(Mobilis::Project)).to be_truthy
  end
end

RSpec.describe Mobilis::RailsProject do
  let(:rails_project) { build(:rails_prime) }
  it "factory works" do
    expect(rails_project.instance_of?(Mobilis::RailsProject)).to be_truthy
  end
end
