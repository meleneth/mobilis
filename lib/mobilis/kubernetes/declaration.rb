# frozen_string_literal: true

module Mobilis
  module Kubernetes
    # Deployment intent only. Workloads and networking objects remain internal.
    class Declaration
      attr_reader :base_domain, :exposures

      def initialize(wildcard)
        unless wildcard.is_a?(String) && wildcard.start_with?("*.")
          raise ArgumentError, "Kubernetes domain must be a wildcard such as *.deva.station"
        end
        @base_domain = wildcard.delete_prefix("*.")
        labels = base_domain.split(".", -1)
        unless labels.size >= 2 && base_domain.bytesize <= 253 && labels.all? { |label| self.class.dns_label?(label) }
          raise ArgumentError, "Invalid Kubernetes wildcard/domain: #{wildcard}"
        end
        @exposures = []
      end

      def self.dns_label?(value)
        value.is_a?(String) && value.bytesize.between?(1, 63) && value.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/)
      end

      def istio(&block)
        raise ArgumentError, "Only one istio block is allowed" if @istio_declared
        raise ArgumentError, "istio requires a block" unless block

        @istio_declared = true
        Istio.new(exposures).instance_exec(&block)
      end

      def to_h
        {domain: "*.#{base_domain}", exposures: exposures}
      end

      def self.from_h(hash)
        new(hash.fetch(:domain)).tap do |declaration|
          declaration.istio do
            Array(hash[:exposures]).each { |exposure| expose exposure.fetch(:name), root: exposure.fetch(:root) }
          end
        end
      end

      class Istio
        def initialize(exposures)
          @exposures = exposures
        end

        def expose(name, root: false)
          raise ArgumentError, "expose requires a service name" unless name.is_a?(String) && !name.empty?
          raise ArgumentError, "root must be true or false" unless [true, false].include?(root)
          # Use the established Mobilis node normalization, never rewrite project identity.
          name = name.tr("_", "-")
          raise ArgumentError, "Duplicate exposure: #{name}" if @exposures.any? { |entry| entry[:name] == name }
          if root && @exposures.any? { |entry| entry[:root] }
            raise ArgumentError, "Only one exposed service may use root: true"
          end
          @exposures << {name: name, root: root}
        end
      end
    end
  end
end
