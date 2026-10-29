# frozen_string_literal: true

module Mobilis
  module Node
    class Airflow < Mobilis::Base::Node
      def initialize(name, isolated_packages: false, **args)
        super(name, **args)
        @isolated_packages = isolated_packages == true
      end

      def isolate_local_packages!
        @isolated_packages = true
      end

      def isolated_packages?
        @isolated_packages
      end

      def to_h
        super.merge(isolated_packages: isolated_packages?)
      end

      def local_package(name, &block)
        package = Mobilis::Model::LocalPythonPackage.new(name)
        block&.call(package)
        use_local_package(package)
      end

      def use_local_package(package)
        raise ArgumentError, "Expected LocalPythonPackage" unless package.is_a?(Mobilis::Model::LocalPythonPackage)
        add_model(package) unless models.include?(package)
        package
      end

      def dag(name, source:)
        raise ArgumentError, "Invalid DAG name" unless name.match?(/\A[a-z][a-z0-9_]*\z/)
        add_model(Mobilis::Model::File.new("dags/#{name}.py", source))
      end

    end
  end
end
