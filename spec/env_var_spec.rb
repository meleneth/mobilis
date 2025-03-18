require "spec_helper"

RSpec.describe Mobilis::EnvVar do
  describe ".[]" do
    it "allows factory-style creation" do
      var = Mobilis::EnvVar["my-var"]
      expect(var.raw).to eq("MY_VAR")
    end
  end

  describe "#initialize" do
    it "normalizes names" do
      expect(Mobilis::EnvVar.new("test-var").raw).to eq("TEST_VAR")
    end
  end

  describe "#child" do
    it "combines names with underscores" do
      base = Mobilis::EnvVar["user-service"]
      expect(base.child("a-db").raw).to eq("USER_SERVICE_A_DB")
    end
  end

  describe "#to_s" do
    it "returns the $VAR format" do
      var = Mobilis::EnvVar["db_url"]
      expect(var.to_s).to eq("$DB_URL")
    end
  end

  describe "#ref" do
    it "returns the ${VAR} format" do
      var = Mobilis::EnvVar["endpoint"]
      expect(var.ref).to eq("${ENDPOINT}")
    end

    it "works with chained children" do
      var = Mobilis::EnvVar["base"].child("url")
      expect(var.ref).to eq("${BASE_URL}")
    end
  end
end
