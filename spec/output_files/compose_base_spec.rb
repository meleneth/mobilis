# frozen_string_literal: true

require "spec_helper"

# Tests for Mobilis::OutputFiles::ComposeBase
RSpec.describe Mobilis::OutputFiles::ComposeBase do
  let(:environment) { "test" }
  let(:metaproject) { build(:metaproject) }
  let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "somerails") }

  subject(:compose_base) { described_class.new(environment, metaproject) }

  describe "#render" do
    it "produces valid YAML output" do
      output = compose_base.render
      expect { YAML.safe_load(output) }.not_to raise_error
    end

    it "includes expected services for the given environment" do
      rails_project
      output = compose_base.render
      parsed = YAML.safe_load(output)

      expect(parsed["include"]).to be_a(Array)
      expect(parsed["include"][0]).to be_a(Hash)
      # Example: expect(parsed['services'].keys).to include('web') if that’s a known default
    end
  end
end
