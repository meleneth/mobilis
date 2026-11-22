# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Browser::Capabilities do
  it "supports basic Rails, Redis and PostgreSQL generation in the browser" do
    system = Mobilis::DSL.build("demo") do
      rails("web", primary_database: postgres("database"), api: true)
      redis("cache")
      connect(from: "web", to: "cache")
    end
    expect(described_class.project(system).browser_generation).to be(true)
    expect(described_class.for_system(system).fetch("web").browser_generation).to be(true)
  end

  it "rejects Rails generator features that require host commands" do
    system = Mobilis::DSL.build("demo") do
      rails("web") { |service| service.add_rails_model("widget") }
    end
    capability = described_class.project(system)
    expect(capability.browser_generation).to be(false)
    expect(capability.reason).to match(/Rails::Model/)
  end

  it "keeps Rails authoring independent from generation capability" do
    source = <<~RUBY
      Mobilis::DSL.generate("demo") do
        rails("web", api: true)
      end
    RUBY
    analysis = Mobilis::Browser::SourceDocument.new(source).analyze
    expect(analysis).to be_valid
    expect(described_class.for_system(analysis.system).fetch("web").browser_generation).to be(true)
  end
end
