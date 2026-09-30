# frozen_string_literal: true

require "fileutils"

module Mobilis
  module Model
    class LocalGem
      attr_reader :name, :path, :require_name, :files

      def initialize(name, path: nil, require_name: nil, files: [])
        @name = name
        @path = path || "../localgems/#{name}"
        @require_name = require_name
        @files = files
        parts = root_path.split("/", -1)
        valid_parts = parts.any? && parts.all? { |part| part.match?(/\A[\w.-]+\z/) && !%w[. ..].include?(part) }
        unless @path.start_with?("../") && valid_parts
          raise ArgumentError, "local gem path must be ../ followed by a directory inside the generated project (for example ../gems/#{name})"
        end
      end

      def write_file(path, content)
        files << Mobilis::Model::File.new(path, content)
        self
      end

      def gem_dependency
        Mobilis::Model::RubyGem.new(name, path: path, require_name: require_name)
      end

      def root_path
        path.sub(%r{\A\.\./}, "")
      end

      def write_files
        # Explicit contents take precedence over the scaffold, including after
        # serialization or when the same gem is written by multiple services.
        generated_files = scaffold_files.merge(files.to_h { |file| [file.path, file.content] })
        generated_files.each do |file_path, content|
          target = ::File.join(root_path, file_path)
          dir = ::File.dirname(target)
          FileUtils.mkdir_p(dir)
          ::File.write(target, content)
        end
      end

      def scaffold_files
        entrypoint = require_name || name
        modules = entrypoint.split("/").map do |part|
          constant = part.split(/[^a-zA-Z0-9]+/).map(&:capitalize).join
          constant = "Gem#{constant}" unless constant.match?(/\A[A-Z]/)
          constant
        end
        implementation = ["# frozen_string_literal: true", ""]
        modules.each_with_index { |constant, index| implementation << "#{"  " * index}module #{constant}" }
        implementation << "#{"  " * modules.length}VERSION = \"0.1.0\""
        modules.length.times { |index| implementation << "#{"  " * (modules.length - index - 1)}end" }

        {
          "#{name}.gemspec" => <<~RUBY,
            # frozen_string_literal: true

            Gem::Specification.new do |spec|
              spec.name = #{name.inspect}
              spec.version = "0.1.0"
              spec.authors = ["Mobilis"]
              spec.summary = #{"Shared #{name} code for the generated services".inspect}
              spec.files = Dir["lib/**/*"]
              spec.require_paths = ["lib"]
            end
          RUBY
          "lib/#{entrypoint}.rb" => "#{implementation.join("\n")}\n",
          "Gemfile" => <<~RUBY,
            source "https://rubygems.org"

            gemspec
            gem "rspec", "~> 3.13"
          RUBY
          ".rspec" => "--require spec_helper\n--format documentation\n",
          "spec/spec_helper.rb" => <<~RUBY,
            # frozen_string_literal: true

            $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
          RUBY
          "spec/local_gem_spec.rb" => <<~RUBY
            # frozen_string_literal: true

            require "spec_helper"

            RSpec.describe #{name.inspect} do
              it "loads the gem implementation" do
                expect { require #{entrypoint.inspect} }.not_to raise_error
              end
            end
          RUBY
        }
      end

      def to_h
        {
          type: self.class.name,
          name: name,
          path: path,
          require_name: require_name,
          files: files.map(&:to_h)
        }.compact
      end

      def self.from_h(hash)
        # @type var path: String?
        path = hash[:path]
        # @type var require_name: String?
        require_name = hash[:require_name]
        # @type var files: Array[Mobilis::file_model_record]
        files = hash[:files] || []

        new(
          hash[:name],
          path: path,
          require_name: require_name,
          files: files.map { |file| Mobilis::Model::File.from_h(file) }
        )
      end
    end
  end
end
