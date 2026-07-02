# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Model::LocalGem do
  it "builds a path-based RubyGem dependency" do
    gem = described_class.new("mel-mnbme", require_name: "mel/mnbme")

    expect(gem.gem_dependency.gemfile_line).to eq('gem "mel-mnbme", path: "../localgems/mel-mnbme", require: "mel/mnbme"')
  end

  it "round trips through a hash" do
    gem = described_class.new("mel-mnbme")
    gem.write_file("lib/mel/mnbme.rb", "# frozen_string_literal: true\n")

    loaded = described_class.from_h(gem.to_h)

    expect(loaded.name).to eq("mel-mnbme")
    expect(loaded.files.first.path).to eq("lib/mel/mnbme.rb")
  end
end
