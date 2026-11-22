# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in mobilis.gemspec
gemspec

gem "debug", ">= 1.10.0"
gem "factory_bot", "~> 6.5.1"
gem "git", "~> 3.0.0"
gem "pry", "~> 0.15.2"
gem "rake", "~> 13.2.1"
gem "rspec", "~> 3.13.0"
gem "simplecov", require: false, group: :test
gem "standard", group: %i[development test]
gem "state_machines-graphviz", group: :development
gem "super_diff", "~> 0.15.0"
gem "webrick", "~> 1.9.1"

group :playground do
  gem "haml", "~> 6.4"
  gem "ruby_wasm", "~> 2.10"
end

group :development do
  gem "steep"
end

gem "awesome_print", "~> 1.9"

gem "foreman", "~> 0.90.0"

# Migration gate: source-backed editing for the browser playground.
gem "diesl", git: "https://github.com/meleneth/diesl.git", ref: "18523d162c79e172a32108fb7914fbaeb5d80f7e", group: [:development, :test, :playground]
