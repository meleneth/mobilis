# frozen_string_literal: true

require "fileutils"
require "json"

module Mobilis
  module Model
    class LocalPythonPackage
      attr_reader :name, :dependencies, :files

      def initialize(name, dependencies: [], files: [])
        raise ArgumentError, "Invalid Python distribution name" unless name.match?(/\A[a-z][a-z0-9-]*[a-z0-9]\z/)

        @name = name
        @dependencies = dependencies
        @files = files
      end

      def module_name
        name.tr("-", "_")
      end

      def write_file(path, content)
        unless path.match?(%r{\A(?:src/#{module_name}/|tests/)[a-zA-Z0-9_/.-]+\.py\z}) &&
            !path.split("/").include?("..")
          raise ArgumentError, "Python package files must be inside src/#{module_name} or tests"
        end
        files << Mobilis::Model::File.new(path, content)
        self
      end

      def depends_on(requirement)
        dependencies << requirement
        self
      end

      def write_files(root)
        scaffold = {
          "src/#{module_name}/__init__.py" => "",
          "tests/test_#{module_name}_import.py" => "def test_import():\n    import #{module_name}\n    assert #{module_name} is not None\n",
          "pyproject.toml" => <<~TOML
            [build-system]
            requires = ["setuptools==80.9.0", "wheel==0.45.1"]
            build-backend = "setuptools.build_meta"

            [project]
            name = #{name.to_json}
            version = "0.1.0"
            requires-python = ">=3.12,<3.15"
            dependencies = #{dependencies.to_json}

            [project.optional-dependencies]
            test = ["pytest>=8,<10"]

            [tool.setuptools.packages.find]
            where = ["src"]

            [tool.pytest.ini_options]
            testpaths = ["tests"]
          TOML
        }
        scaffold.merge(files.to_h { |file| [file.path, file.content] }).each do |path, content|
          target = ::File.join(root, path)
          FileUtils.mkdir_p(::File.dirname(target))
          ::File.write(target, content)
        end
      end

      def to_h
        {type: self.class.name, name: name, dependencies: dependencies, files: files.map(&:to_h)}
      end

      def self.from_h(hash)
        new(hash[:name], dependencies: hash[:dependencies] || [],
            files: Array(hash[:files]).map { |file| Mobilis::Model::File.from_h(file) })
      end
    end
  end
end
