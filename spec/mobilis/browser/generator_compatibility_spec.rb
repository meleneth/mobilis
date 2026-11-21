# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mobilis::Browser::GeneratorCompatibility do
  let(:corpus_root) do
    File.expand_path("../../../generator_compatibility/captures", __dir__)
  end
  subject(:compatibility) { described_class.new(corpus_root:) }

  it "exposes the exact captured invocation and required workspace paths" do
    expect(compatibility.manifests).to eq(
      [
        {
          generator: "rspec:install",
          version: "8.1.0",
          arguments: [],
          input_paths: [".rspec", "config/application.rb", "config/environment.rb", "spec/rails_helper.rb", "spec/spec_helper.rb"]
        }
      ]
    )
  end

  it "returns an encoded creation plan without mutating the supplied snapshot" do
    encoded_files = {
      "config/application.rb" => Base64.strict_encode64("class Application; end\n"),
      "config/environment.rb" => Base64.strict_encode64("require_relative \"application\"\n"),
      ".rspec" => nil,
      "spec/rails_helper.rb" => nil,
      "spec/spec_helper.rb" => nil
    }

    plan = compatibility.plan(
      generator: "rspec:install",
      version: "8.1.0",
      arguments: [],
      encoded_files:
    )

    expect(plan.fetch(:created)).to contain_exactly(".rspec", "spec/rails_helper.rb", "spec/spec_helper.rb")
    expect(Base64.strict_decode64(plan.dig(:writes, ".rspec", :content))).to eq("--require spec_helper\n")
    expect(encoded_files.fetch(".rspec")).to be_nil
  end

  it "rejects missing prerequisites and conflicting user files" do
    expect do
      compatibility.plan(
        generator: "rspec:install",
        version: "8.1.0",
        arguments: [],
        encoded_files: {}
      )
    end.to raise_error(Mobilis::GeneratorCompatibility::WorkspaceConflictError, /prerequisites/)

    expect do
      compatibility.plan(
        generator: "rspec:install",
        version: "8.1.0",
        arguments: [],
        encoded_files: {
          "config/application.rb" => Base64.strict_encode64("application\n"),
          "config/environment.rb" => Base64.strict_encode64("environment\n"),
          ".rspec" => Base64.strict_encode64("user settings\n")
        }
      )
    end.to raise_error(Mobilis::GeneratorCompatibility::WorkspaceConflictError, /\.rspec/)
  end
end
