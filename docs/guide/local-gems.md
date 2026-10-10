# Shared local gems

Rails and Rack services can declare a buildable local gem without supplying any
files, then share it with other services:

```ruby
require "mobilis"

Mobilis::DSL.generate("shared-services") do
  shared = nil
  rails("accounts") do |service|
    shared = service.local_gem("shared-library", path: "../gems/shared-library")
  end
  rails("billing") { |service| service.use_local_gem(shared) }
end
```

The default path is `../localgems/<name>`. Custom paths must start with `../`
and point inside the generated project, such as `../gems/shared-library` or
`../vendor/gems/shared-library`. Both service writers copy the consumed gem
directories into the image at the matching paths. Rails includes them in both
build and runtime stages and in its Docker build context allowlist.

Each gem gets a gemspec (version `0.1.0`), a Ruby entrypoint containing a module
and `VERSION`, a Gemfile with RSpec, and a passing load test. The entrypoint is
`lib/<name>.rb`, or `lib/<require_name>.rb` when `require_name:` is supplied.
From the generated gem directory, run `bundle install`, `bundle exec rspec`,
or `gem build <name>.gemspec`.

## Supplying implementation and tests

Inside a service configuration block, supply implementation and tests during generation with `write_file`; supplied
files replace the corresponding defaults. Omitted files keep their defaults:

```ruby
service.local_gem("shared-library", path: "../gems/shared-library",
                  require_name: "shared/library") do |gem|
  gem.write_file("lib/shared/library.rb", <<~RUBY)
    module Shared
      module Library
        def self.greeting = "Hello"
      end
    end
  RUBY
  gem.write_file("spec/local_gem_spec.rb", <<~RUBY)
    require "spec_helper"
    require "shared/library"

    RSpec.describe Shared::Library do
      it("greets") { expect(described_class.greeting).to eq("Hello") }
    end
  RUBY
end
```

To declare runtime dependencies or different metadata, supply
`<name>.gemspec` too. `write_file` also accepts `File.read(...)` to include existing
source files at generation time. Gem contents are serialized with the system configuration.
Local gem source is baked into service images; rebuild the image after editing it.

## Paths and generated files

For the example above, the generated tree contains:

```text
generate/
  accounts/
  billing/
  gems/shared-library/
    shared-library.gemspec
    Gemfile
    lib/shared-library.rb
    .rspec
    spec/spec_helper.rb
    spec/local_gem_spec.rb
```

`path:` is relative to a service directory, not a source directory to import. Mobilis writes the gem under the generated project. To import existing code, read its files and pass the contents to `write_file`.

`require_name: "shared/library"` changes the default entrypoint to `lib/shared/library.rb` and the dependency's Bundler require option. The default scaffold defines `Shared::Library::VERSION`; without that option, `shared-library` defines `SharedLibrary::VERSION`. Replacing the implementation replaces the entire file, so include any constants your code needs.

`local_gem` both declares the gem and adds it to that service. `use_local_gem` attaches the returned `Mobilis::Model::LocalGem` to another service; it takes the object, not a gem name. Both Rails and Rack support these methods.

## Build and test the gem

From `generate/gems/shared-library`:

```sh
bundle install
bundle exec rspec
gem build shared-library.gemspec
```

The generated smoke test checks that the entrypoint loads. Add behavior tests for your library; the default test does not verify your application logic.

## Image build contexts

Rails services with local gems use the generated project root as their Docker build context and a service-specific `Dockerfile.dockerignore` to include only the service and consumed gems. The gem files are copied into both build and runtime stages. Rack uses the project root context and copies its consumed gems before installing dependencies.

Use the generated Compose wrappers to retain those contexts. After editing a shared gem, rebuild each consuming image and recreate its container, for example:

```sh
./dc_dev build accounts billing
./dc_dev up -d accounts billing
```

The shared gem is baked into the images; do not expect a service source mount to reload it. Work in the generated tree after scaffolding rather than rerunning generation over your edits.

## Complete examples

- [Two Rails services sharing a gem](https://github.com/meleneth/mobilis/blob/core/scripts/19_two_rails_local_gem.rb)
- [Rack game services with a custom gemspec and dependencies](https://github.com/meleneth/mobilis/blob/core/scripts/18_mnbme_otel_system.rb)
