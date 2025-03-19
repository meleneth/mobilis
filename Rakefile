# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# require "rubocop/rake_task"
#
# RuboCop::RakeTask.new

# task default: %i[spec rubocop]
task default: %i[spec]

# Starts a simple web server to serve the coverage report
namespace :coverage do
  desc "Serve the coverage report at http://localhost:8000"
  task :serve do
    puts "Serving coverage report at http://localhost:8000 (Ctrl+C to stop)"
    exec "ruby -run -e httpd coverage -p 8000"
  end
end
