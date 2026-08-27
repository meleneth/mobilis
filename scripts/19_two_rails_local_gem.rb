#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("generate") do
  shared_gem = nil

  rails("accounts") do |service|
    shared_gem = service.local_gem("shared-library", require_name: "shared/library") do |gem|
      gem.write_file("shared-library.gemspec", <<~RUBY)
        # frozen_string_literal: true

        Gem::Specification.new do |spec|
          spec.name = "shared-library"
          spec.version = "0.1.0"
          spec.authors = ["Mobilis"]
          spec.summary = "Shared code for the generated Rails services"
          spec.files = Dir["lib/**/*"]
          spec.require_paths = ["lib"]
        end
      RUBY

      gem.write_file("lib/shared/library.rb", <<~RUBY)
        # frozen_string_literal: true

        module Shared
          module Library
            VERSION = "0.1.0"
          end
        end
      RUBY
    end
  end

  rails("billing") do |service|
    service.use_local_gem(shared_gem)
  end
end
