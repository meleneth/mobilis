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

  it "emits actual ordered file deltas at Mobilis's Git commit boundaries" do
    Dir.mktmpdir do |directory|
      system = Mobilis::DSL.build("browser-demo") do
        postgres("database")
        redis("cache")
        connect(from: "cache", to: "database")
      end
      result = described_class.new(workspace: directory).call(system)
      expect(result.steps.length).to be > 3
      expect(result.steps.first.fetch(:message)).to eq("[mobilis] Basic project files")

      restored = {}
      result.steps.each do |step|
        expect(step.fetch(:message)).to start_with("[mobilis] ")
        expect(step.fetch(:writes)).not_to be_empty
        step.fetch(:deletes).each { |name| restored.delete(name) }
        restored.merge!(step.fetch(:writes))
      end
      expect(restored).to eq(result.files)
      expect(result.steps.map { |step| step.fetch(:message) })
        .to include("[mobilis] Compose overrides", "[mobilis] Mobilis system config")
    end
  end

  it "rejects host-dependent models instead of exporting incomplete generator output" do
    Dir.mktmpdir do |directory|
      system = Mobilis::DSL.build("browser-demo") do
        rails("app") { |service| service.add_rails_model("widget") }
      end
      expect { described_class.new(workspace: directory).call(system) }
        .to raise_error(ArgumentError, /host-dependent models/)
    end
  end
end
