require "spec_helper"

RSpec.describe Mobilis::CommandLine do
  let(:subject) { Mobilis::CommandLine }
  describe "#parse_args" do
    it "handles default case" do
      options = subject.parse_args([])
      expect(options[:subcommand]).to eq :interactive
    end
    it "handles 'load some_file.smth'" do
      options = subject.parse_args(["load", "some_file.smth"])
      expect(options[:subcommand]).to eq :load
      expect(options[:filename]).to eq "some_file.smth"
    end
    it "handles 'build some_file.smth'" do
      options = subject.parse_args(["build", "some_file.smth"])
      expect(options[:subcommand]).to eq :build
      expect(options[:filename]).to eq "some_file.smth"
    end
    it "handles 'help'" do
      options = subject.parse_args(["help"])
      expect(options[:subcommand]).to eq :help
    end
  end
end
