# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Browser::AuthoringBundle do
  it "exports exact DSL source and the existing CLI input format" do
    source = <<~RUBY
      require "mobilis"
      Mobilis::DSL.generate("demo") do
        rails("web")
      end
    RUBY
    analysis = Mobilis::Browser::SourceDocument.new(source).analyze
    files = described_class.new(source, analysis.system).files

    expect(files.fetch("mobilis.rb")).to eq(source)
    expect(Mobilis::System.from_json(files.fetch("mobilis-system.json")).node_count).to eq(1)
    expect(files.fetch("README.md")).to include("bundle exec ruby mobilis.rb")
    expect(files.fetch("README.md")).to include("bundle exec mobilis generate mobilis-system.json")
  end
end
