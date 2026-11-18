# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Browser::Capabilities do
  it "derives browser compatibility from the realized service writer" do
    postgres = Mobilis::DSL.build("demo") { postgres("database") }
    rails = Mobilis::DSL.build("demo") { rails("web") }

    expect(described_class.project(postgres).browser_generation).to be(true)
    expect(described_class.project(rails).browser_generation).to be(false)
    expect(described_class.project(rails).reason).to include("rails new")
  end

  it "marks a mixed project as local-only instead of permitting partial output" do
    system = Mobilis::DSL.build("demo") do
      postgres("database")
      rails("web")
    end

    expect(described_class.project(system).browser_generation).to be(false)
  end

  it "keeps Rails authoring independent from generation capability" do
    source = <<~RUBY
      Mobilis::DSL.generate("demo") do
        rails("web", api: true)
      end
    RUBY
    analysis = Mobilis::Browser::SourceDocument.new(source).analyze

    expect(analysis).to be_valid
    expect(described_class.for_system(analysis.system).fetch("web").browser_generation).to be(false)
  end
end
