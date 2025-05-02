# frozen_string_literal: true

require "spec_helper"
require "mobilis/auto_vivify"

RSpec.describe Mobilis::AutoVivify do
  let(:auto) { described_class.new }

  describe "Array behavior" do
    it "auto-vivifies to an array when << is used" do
      auto["volumes"] << "/data"
      expect(auto.to_h["volumes"]).to eq(["/data"])
    end

    it "appends multiple values cleanly" do
      auto["volumes"] << "/data"
      auto["volumes"] << "/var"
      expect(auto.to_h["volumes"]).to eq(["/data", "/var"])
    end
  end

  describe "Hash behavior" do
    it "auto-vivifies to a hash when []= is used" do
      auto["env"]["RAILS_ENV"] = "test"
      expect(auto.to_h["env"]).to eq({ "RAILS_ENV" => "test" })
    end

    it "supports nested assignments" do
      auto["env"]["RAILS_ENV"] = "test"
      auto["env"]["DEBUG"] = "1"
      expect(auto.to_h["env"]).to eq({ "RAILS_ENV" => "test", "DEBUG" => "1" })
    end
  end

  describe "type enforcement" do
    it "raises if array is treated as a hash" do
      auto["volumes"] << "/data"
      expect do
        auto["volumes"]["not"] = "allowed"
      end.to raise_error(TypeError)
    end

    it "raises if hash is treated as an array" do
      auto["env"]["RAILS_ENV"] = "test"
      expect do
        auto["env"] << "oops"
      end.to raise_error(TypeError)
    end
  end

  describe "JSON and hash export" do
    it "serializes to clean nested hashes and arrays" do
      auto["volumes"] << "/data"
      auto["env"]["RAILS_ENV"] = "production"

      json = JSON.parse(auto.to_serial.to_json)
      expect(json).to eq({
                           "volumes" => ["/data"],
                           "env" => { "RAILS_ENV" => "production" }
                         })

      hash = auto.to_h
      expect(hash).to eq({
                           "volumes" => ["/data"],
                           "env" => { "RAILS_ENV" => "production" }
                         })
    end
  end
  it "vivifies deeply even when merge! is called with nested hashes" do
    av = described_class.new
    av[:compose][:services].merge!({ web: { ports: [3000] } })

    # Should auto-vivify the web service and allow access to inner keys
    expect { av[:compose][:services][:web][:ports] << 4000 }.not_to raise_error

    expect(av[:compose][:services][:web][:ports]).to eq([3000, 4000])
  end
end
