# frozen_string_literal: true

require_relative "lib/mobilis/version"

Gem::Specification.new do |spec|
  spec.name = "mobilis"
  spec.version = Mobilis::VERSION
  spec.authors = ["Meleneth"]
  spec.email = ["meleneth@gmail.com"]

  spec.summary = "Generate and scaffold multiple projects and a docker compose file"
  spec.homepage = "https://github.com/meleneth/mobilis"
  spec.required_ruby_version = ">= 3.0.0"
  spec.licenses = ["MIT"]
  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/meleneth/mobilis"
  spec.metadata["changelog_uri"] = "https://github.com/meleneth/mobilis/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.executables << "mobilis"

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "awesome_print"
  spec.add_dependency "optimist"
  spec.add_dependency "pry"
  spec.add_dependency "state_machines"
  spec.add_dependency "table_print"
  spec.add_dependency "tty-prompt"
  spec.add_dependency "git"

  spec.add_development_dependency "super_diff"
  spec.add_development_dependency "simplecov"

  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
