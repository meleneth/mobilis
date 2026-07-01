# frozen_string_literal: true

RSpec.describe Mobilis::Plugin::RailsBuilder do
  it "does not use root ids for builder user arguments" do
    builder = described_class.allocate

    expect(builder.host_user_id).not_to eq(0)
    expect(builder.host_group_id).not_to eq(0)
  end

  it "pins Bundler to the version bundled with the configured Ruby image" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        described_class.allocate.create_rails_builder_dockerfile

        expect(File.read("Dockerfile")).to include(
          "RUN gem install bundler -v #{Mobilis::ContainerVersions::BUNDLER}"
        )
      end
    end
  end
end
