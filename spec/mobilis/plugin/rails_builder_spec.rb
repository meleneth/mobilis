# frozen_string_literal: true

RSpec.describe Mobilis::Plugin::RailsBuilder do
  it "does not use root ids for builder user arguments" do
    builder = described_class.allocate

    expect(builder.host_user_id).not_to eq(0)
    expect(builder.host_group_id).not_to eq(0)
  end
end
