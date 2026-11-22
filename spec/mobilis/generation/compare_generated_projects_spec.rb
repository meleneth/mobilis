# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe "Generated Git project parity comparator" do
  def git(root, *args)
    out, err, status = Open3.capture3("git", "-C", root, *args)
    expect(status.success?).to be(true), err
    out
  end

  def repository(root, content = "same bytes\n")
    FileUtils.mkdir_p(root)
    git(root, "init", "-q")
    File.binwrite(File.join(root, "README.md"), content)
    git(root, "add", ".")
    git(root, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
      "commit", "-qm", "[mobilis] Basic project files")
  end

  it "accepts identical commits and rejects changed content" do
    Dir.mktmpdir do |tmp|
      native = File.join(tmp, "native")
      browser = File.join(tmp, "browser")
      repository(native)
      repository(browser)

      comparator = File.expand_path("../../../scripts/compare_generated_projects", __dir__)
      _output, status = Open3.capture2e(RbConfig.ruby, comparator, native, browser)
      expect(status.success?).to be(true)

      File.binwrite(File.join(browser, "README.md"), "different bytes\n")
      git(browser, "add", ".")
      git(browser, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
        "commit", "-qm", "[mobilis] Changed")
      output, status = Open3.capture2e(RbConfig.ruby, comparator, native, browser)
      expect(status.success?).to be(false)
      expect(output).to include("Different bytes: 1", "Commit boundaries differ:")
    end
  end
end
