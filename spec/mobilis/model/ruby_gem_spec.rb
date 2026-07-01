# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Model::RubyGem do
  it "builds bundle add args for a plain gem" do
    gem = described_class.new("view_component")

    expect(gem.bundle_add_args).to eq(["view_component"])
  end

  it "builds bundle add args for a git sourced gem" do
    gem = described_class.new(
      "retroui-rails",
      git: "https://github.com/meleneth/retroui-rails.git",
      branch: "main",
      require_name: "retro_ui/rails"
    )

    expect(gem.bundle_add_args).to eq([
                                        "retroui-rails",
                                        "--git",
                                        "https://github.com/meleneth/retroui-rails.git",
                                        "--branch",
                                        "main",
                                        "--require",
                                        "retro_ui/rails"
                                      ])
  end

  it "round trips through a hash" do
    gem = described_class.new("redis", group: "development,test")

    expect(described_class.from_h(gem.to_h).to_h).to eq(gem.to_h)
  end
end
