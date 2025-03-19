# frozen_string_literal: true

RSpec.describe "Redis Instance" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_redis_instance "cache"
  end
end
