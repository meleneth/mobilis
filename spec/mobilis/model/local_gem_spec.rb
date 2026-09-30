# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"
require "bundler"

RSpec.describe Mobilis::Model::LocalGem do
  it "builds a path-based RubyGem dependency" do
    gem = described_class.new("mel-mnbme", require_name: "mel/mnbme")

    expect(gem.gem_dependency.gemfile_line).to eq('gem "mel-mnbme", path: "../localgems/mel-mnbme", require: "mel/mnbme"')
  end

  it "round trips through a hash" do
    gem = described_class.new("mel-mnbme")
    gem.write_file("lib/mel/mnbme.rb", "# frozen_string_literal: true\n")

    loaded = described_class.from_h(gem.to_h)

    expect(loaded.name).to eq("mel-mnbme")
    expect(loaded.files.first.path).to eq("lib/mel/mnbme.rb")
  end

  it "rejects paths that cannot be reproduced relative to a service in the image" do
    ["gems/shared", "/gems/shared", "../../shared", "../gems/../shared", "../"].each do |path|
      expect { described_class.new("shared", path: path) }.to raise_error(ArgumentError, /local gem path/)
    end
  end

  [nil, "shared/library"].each do |require_name|
    it "builds, installs, and tests a gem with no supplied contents (require: #{require_name.inspect})" do
      gem = described_class.new("shared-library", path: "../gems/shared-library", require_name: require_name)

      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { gem.write_files }
        gem_dir = "#{dir}/gems/shared-library"
        output = run_generated(gem_dir, "-S", "gem", "build", "shared-library.gemspec")
        expect(output).to include("Successfully built RubyGem")
        expect(File).to exist("#{gem_dir}/shared-library-0.1.0.gem")
        run_bundle(gem_dir, "install", "--local")
        expect(run_bundle(gem_dir, "exec", "rspec")).to include("1 example, 0 failures")

        # Exercise the same path dependency and automatic require used by Rails.
        service_dir = "#{dir}/service"
        FileUtils.mkdir_p(service_dir)
        File.write("#{service_dir}/Gemfile", "#{gem.gem_dependency.gemfile_line}\n")
        run_bundle(service_dir, "install", "--local")
        namespace = require_name ? "Shared::Library" : "SharedLibrary"
        command = %(require "bundler/setup"; Bundler.require; puts #{namespace}::VERSION)
        expect(run_bundle(service_dir, "exec", "ruby", "-e", command)).to include("0.1.0")
      end
    end
  end

  it "preserves supplied implementation, gemspec, and specs through JSON and repeated generation" do
    system = Mobilis::System.new("demo")
    first = Mobilis::Node::Rails.new("accounts")
    gem = first.local_gem("shared-library", path: "../gems/shared-library", require_name: "shared/library")
    gem.write_file("lib/shared/library.rb", "module Shared; module Library; def self.answer = 42; end; end\n")
    gem.write_file("shared-library.gemspec", <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = "shared-library"
        spec.version = "2.0.0"
        spec.authors = ["Example"]
        spec.summary = "Custom implementation"
        spec.files = Dir["lib/**/*"]
      end
    RUBY
    gem.write_file("spec/local_gem_spec.rb", <<~RUBY)
      require "spec_helper"
      require "shared/library"
      RSpec.describe Shared::Library do
        it("returns the supplied answer") { expect(described_class.answer).to eq(42) }
      end
    RUBY
    second = Mobilis::Node::Rails.new("billing")
    second.use_local_gem(gem)
    system << first
    system << second
    loaded = Mobilis::System.from_h(JSON.parse(system.to_json, symbolize_names: true))

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { loaded.each_config_node { |node| node.local_gems.each(&:write_files) } }
      gem_dir = "#{dir}/gems/shared-library"
      expect(File.read("#{gem_dir}/lib/shared/library.rb")).to eq(gem.files.first.content)
      expect(run_generated(gem_dir, "-S", "gem", "build", "shared-library.gemspec")).to include("Version: 2.0.0")
      run_bundle(gem_dir, "install", "--local")
      expect(run_bundle(gem_dir, "exec", "rspec")).to include("1 example, 0 failures")
    end
  end

  it "uses supplied implementation with the default gemspec and smoke test" do
    gem = described_class.new("shared", require_name: "shared")
    gem.write_file("lib/shared.rb", "module Shared; def self.answer = 42; end\n")

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { gem.write_files }
      gem_dir = "#{dir}/localgems/shared"
      run_bundle(gem_dir, "install", "--local")
      expect(run_bundle(gem_dir, "exec", "rspec")).to include("1 example, 0 failures")
      expect(run_bundle(gem_dir, "exec", "ruby", "-rshared", "-e", "puts Shared.answer")).to include("42")
    end
  end

  def run_bundle(dir, *args)
    run_generated(dir, Gem.bin_path("bundler", "bundle"), *args)
  end

  def run_generated(dir, *args)
    output, status = Bundler.with_unbundled_env do
      # Keep Bundler's install lock and user cache inside the disposable project,
      # while resolving RSpec from the gems already installed for this test suite.
      env = {"GEM_HOME" => "#{dir}/.gem-home", "GEM_PATH" => Gem.path.join(File::PATH_SEPARATOR),
             "BUNDLE_USER_HOME" => "#{dir}/.bundle-user"}
      Open3.capture2e(env, RbConfig.ruby, *args, chdir: dir)
    end
    expect(status.success?).to be(true), output
    output
  end
end
