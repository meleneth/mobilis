# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Compose::DependsOn do
  let(:base) do
    described_class.new.tap do |d|
      d.register("db", { "condition" => "service_healthy" })
      d.register("redis", {})
    end
  end

  let(:override) do
    described_class.new(base: base).tap do |d|
      d.register("redis", { "condition" => "service_started" })
      d.register("search", {})
    end
  end

  describe "#as_json" do
    it "returns registered dependencies without base" do
      simple = described_class.new
      simple.register("web", { "condition" => "service_healthy" })

      expect(simple.as_json).to eq({
        "web" => { "condition" => "service_healthy" }
      })
    end

    it "includes base dependencies if base is present" do
      expect(override.as_json).to eq({
        "db"     => { "condition" => "service_healthy" },
        "redis"  => { "condition" => "service_started" },
        "search" => {}
      })
    end
  end

  describe "#to_json" do
    it "serializes as expected" do
      expect(JSON.parse(override.to_json)).to eq({
        "db"     => { "condition" => "service_healthy" },
        "redis"  => { "condition" => "service_started" },
        "search" => {}
      })
    end
  end
end
