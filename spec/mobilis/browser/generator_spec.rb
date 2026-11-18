# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Browser::Generator do
  it "uses Mobilis writers to produce a static project" do
    Dir.mktmpdir do |directory|
      system = Mobilis::DSL.build("browser-demo") { postgres("database") }
      result = described_class.new(workspace: directory).call(system)

      expect(result.files).to include(
        "compose/database.yml",
        "development-compose.yml",
        "mobilis-system.json"
      )
      expected = File.read(File.expand_path("../../fixtures/browser/postgres-compose.yml", __dir__))
      expect(result.files.fetch("compose/database.yml")).to eq(expected)
    end
  end

  it "produces stable files when generation is repeated" do
    Dir.mktmpdir do |directory|
      system = Mobilis::DSL.build("browser-demo") { postgres("database") }
      generator = described_class.new(workspace: directory)

      expect(generator.call(system).files).to eq(generator.call(system).files)
    end
  end

  it "reports services whose real writer requires external processes" do
    Dir.mktmpdir do |directory|
      system = Mobilis::DSL.build("browser-demo") { rails("app") }

      expect { described_class.new(workspace: directory).call(system) }
        .to raise_error(ArgumentError, /requires local generation.*Rails writer invokes Docker/)
    end
  end
end
