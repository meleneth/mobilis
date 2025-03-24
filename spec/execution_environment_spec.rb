# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::ExecutionEnvironment do
  subject { described_class.new(env_value) }

  context "when environment is development" do
    let(:env_value) { "development" }

    it { expect(subject.is_dev?).to be true }
    it { expect(subject.is_test?).to be false }
    it { expect(subject.is_production?).to be false }
    it { expect(subject.is_staging?).to be false }
    it { expect(subject.to_s).to eq "development" }
  end

  context "when environment is test" do
    let(:env_value) { "test" }

    it { expect(subject.is_dev?).to be false }
    it { expect(subject.is_test?).to be true }
    it { expect(subject.is_production?).to be false }
    it { expect(subject.is_staging?).to be false }
    it { expect(subject.to_s).to eq "test" }
  end

  context "when environment is production" do
    let(:env_value) { "production" }

    it { expect(subject.is_dev?).to be false }
    it { expect(subject.is_test?).to be false }
    it { expect(subject.is_production?).to be true }
    it { expect(subject.is_staging?).to be false }
    it { expect(subject.to_s).to eq "production" }
  end

  context "when environment is staging" do
    let(:env_value) { "staging" }

    it { expect(subject.is_dev?).to be false }
    it { expect(subject.is_test?).to be false }
    it { expect(subject.is_production?).to be false }
    it { expect(subject.is_staging?).to be true }
    it { expect(subject.to_s).to eq "staging" }
  end

  context "when environment is uppercase" do
    let(:env_value) { "PRODUCTION" }

    it "converts to symbol and downcases string output" do
      expect(subject.is_production?).to be true
      expect(subject.to_s).to eq "production"
    end
  end
end
