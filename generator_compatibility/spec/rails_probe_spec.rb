# frozen_string_literal: true

require "json"
require "open3"
require "rails/generators/rails/app/app_generator"
require "tmpdir"

RSpec.describe "Rails generator compatibility probe" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:options) { JSON.parse(File.read(File.join(root, "rails_app_options.json"))) }

  it "invokes the real native Rails application generator API" do
    Dir.mktmpdir("mobilis-native-rails") do |destination|
      starting_directory = Dir.pwd
      begin
        Rails::Generators::AppGenerator.start(options, destination_root: destination)
      ensure
        Dir.chdir(starting_directory)
      end
      project = File.join(destination, "probe")

      expect(File).to exist(File.join(project, "Gemfile"))
      expect(File).to exist(File.join(project, "config/application.rb"))
      expect(File).to exist(File.join(project, "bin/rails"))
      expect(Dir.glob("**/*", File::FNM_DOTMATCH, base: project).count { |entry| File.file?(File.join(project, entry)) })
        .to eq(44)
    end
  end

  it "records the standard Ruby WASM bigdecimal blocker without pretending generation succeeded" do
    Dir.mktmpdir("mobilis-wasm-rails") do |destination|
      manifest = File.join(destination, "manifest.json")
      build_stdout, build_stderr, build_status = Open3.capture3(
        RbConfig.ruby,
        File.join(root, "build_probe_manifest.rb"),
        chdir: root
      )
      expect(build_status).to be_success, build_stderr
      File.write(manifest, build_stdout)

      stdout, stderr, status = Open3.capture3(
        "node",
        "--no-warnings",
        File.join(root, "probe_rails_wasm.mjs"),
        manifest,
        destination,
        chdir: root
      )

      expect(status).not_to be_success
      expect(stdout).to include("create  config/locales/en.yml")
      expect(stderr).to include("cannot load such file -- bigdecimal")
      expect(File).not_to exist(File.join(destination, "probe", "config", "credentials.yml.enc"))
    end
  end
end
