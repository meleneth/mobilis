# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Primitives::PortMap do
  it "works #badname" do
    instance = Mobilis::Primitives::PortMap.new(31_337, 2166, "An Example Port Mapping")
    expect(instance.to_compose).to eq("31337:2166")
  end
end
