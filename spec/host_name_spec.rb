require "spec_helper"

RSpec.describe Mobilis::HostName do
  describe ".[]" do
    it "allows factory-style creation" do
      host = Mobilis::HostName["My_Host"]
      expect(host.raw).to eq("my-host")
    end
  end

  describe "#initialize" do
    it "normalizes input to lowercase dash-separated form" do
      expect(Mobilis::HostName.new("Test_Host  Name").raw).to eq("test-host-name")
    end

    it "splits camel-case input with dashes" do
      expect(Mobilis::HostName.new("UserDB").raw).to eq("user-db")
      expect(Mobilis::HostName.new("SuperVIPClient").raw).to eq("super-vip-client")
    end
  end

  describe "#child" do
    it "appends child names with a dash" do
      base = Mobilis::HostName["api"]
      expect(base.child("internal").raw).to eq("api-internal")
    end

    it "supports chaining children" do
      base = Mobilis::HostName["service"]
      chained = base.child("db").child("replica")
      expect(chained.raw).to eq("service-db-replica")
    end
  end

  describe "#to_s" do
    it "returns the normalized string" do
      host = Mobilis::HostName["App Server"]
      expect(host.to_s).to eq("app-server")
    end
  end
end
