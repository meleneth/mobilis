#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

Mobilis::DSL.generate("generate") do
  shared_gem = nil

  rails("accounts") do |service|
    # The gemspec and RSpec setup are supplied by Mobilis. This block is optional:
    # omitting it generates a loadable module and a passing smoke test.
    shared_gem = service.local_gem("shared-library", path: "../gems/shared-library", require_name: "shared/library") do |gem|
      gem.write_file("lib/shared/library.rb", <<~RUBY)
        # frozen_string_literal: true

        module Shared
          module Library
            VERSION = "0.1.0"
            def self.greeting = "Hello from the shared gem"
          end
        end
      RUBY
      gem.write_file("spec/local_gem_spec.rb", <<~RUBY)
        require "spec_helper"
        require "shared/library"

        RSpec.describe Shared::Library do
          it "provides a shared greeting" do
            expect(described_class.greeting).to eq("Hello from the shared gem")
          end
        end
      RUBY
    end
  end

  rails("billing") do |service|
    service.use_local_gem(shared_gem)
  end
end
