# frozen_string_literal: true

module Mobilis
  module Node
    class Airflow < Mobilis::Base::Node
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
