# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "diesl"
  spec.version = "0.1.0"
  spec.summary = "Conservative source editing primitives for Ruby DSLs"
  spec.authors = ["Diesl contributors"]
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = ["lib"]
  spec.add_dependency "prism", ">= 1.0"
end
