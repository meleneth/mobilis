# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Primitives::EmitVar do
  describe ".for" do
    it "builds a resolved and specific pair from service/type" do
      var = Mobilis::Primitives::EmitVar.for("user", "postgres_url", "db://x")
      expect(var.container_name).to eq("POSTGRES_URL")
      expect(var.envfile_name).to eq("USER_POSTGRES_URL")
      expect(var.value).to eq("db://x")
      expect(var.compose_repr).to eq("POSTGRES_URL=${USER_POSTGRES_URL}")
    end
  end

  describe "initialization and normalization" do
    let(:var) { described_class.new("my-var", "foo-bar", "xyz") }

    it "normalizes container_name and envfile_name" do
      expect(var.container_name).to eq("MY_VAR")
      expect(var.envfile_name).to eq("FOO_BAR")
      expect(var.value).to eq("xyz")
    end
  end

  describe "with envfile_name" do
    subject(:var) { described_class.new("APP_URL", "MY_APP_URL", "https://example.com") }

    it "has both names and value" do
      expect(var.container_name).to eq("APP_URL")
      expect(var.envfile_name).to eq("MY_APP_URL")
      expect(var.value).to eq("https://example.com")
    end

    it "has_envfile_name? returns true" do
      expect(var.has_envfile_name?).to be_truthy
    end

    it "emits correct bash and ref syntax" do
      expect(var.compose_repr).to eq("APP_URL=${MY_APP_URL}")
      expect(var.env_repr).to eq("MY_APP_URL=https://example.com")
    end

    it "has ref methods for both names" do
      expect(var.container_var_ref).to eq("${APP_URL}")
      expect(var.env_var_ref).to eq("${MY_APP_URL}")
    end

    describe "#as" do
      it "makes a new value" do
        var2 = var.as("OTHER_KEY")
        expect(var2.container_name).to eq("OTHER_KEY")
        expect(var.container_name).to eq("APP_URL")

        expect(var2.envfile_name).to eq("MY_APP_URL")
        expect(var2.value).to eq("https://example.com")
      end
    end
  end

  describe "without envfile_name" do
    subject(:var) { described_class.new("RAILS_MAX_THREADS", nil, "5") }

    it "has container_name only" do
      expect(var.container_name).to eq("RAILS_MAX_THREADS")
      expect(var.envfile_name).to eq(nil)
      expect(var.value).to eq("5")
    end

    it "has_envfile_name? is false" do
      expect(var.has_envfile_name?).to_not be_truthy
    end
  end
end
