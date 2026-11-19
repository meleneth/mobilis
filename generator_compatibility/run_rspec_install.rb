# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "rails/generators"
require "generators/rspec/install/install_generator"

destination, *arguments = ARGV
abort "usage: ruby run_rspec_install.rb DESTINATION [GENERATOR_ARGUMENTS...]" unless destination

Rspec::Generators::InstallGenerator.start(arguments, destination_root: File.expand_path(destination))
