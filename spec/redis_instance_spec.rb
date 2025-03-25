# frozen_string_literal: true

RSpec.describe "Redis Instance" do
  let(:project) { build(:metaproject) }

  it "is addable" do
    project.add_redis_instance "cache"
  end
end
