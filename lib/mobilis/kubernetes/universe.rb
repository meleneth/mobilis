# frozen_string_literal: true

module Mobilis
  module Kubernetes
    class Universe
      ENVIRONMENTS = {"development" => "dev", "test" => "test", "production" => "prod"}.freeze
      attr_reader :project, :environment, :namespace, :domain, :services, :public_services, :realized_env

      def initialize(realized_env, declaration)
        @realized_env = realized_env
        @project = realized_env.meta_project_name
        validate_label!(project, "project")
        @environment = ENVIRONMENTS.fetch(realized_env.to_s)
        @namespace = "#{project}-#{environment}"
        validate_label!(namespace, "namespace")
        @domain = "#{project}.#{environment}.#{declaration.base_domain}"
        @services = realized_env.realized_nodes.sort_by(&:name)
        services.each { |node| validate_label!(node.name, "service") }
        raise ArgumentError, "Kubernetes service name collision" unless services.map(&:name).uniq.size == services.size

        @public_services = declaration.exposures.to_h do |exposure|
          node = services.find { |service| service.name == exposure[:name] }
          raise ArgumentError, "Unknown exposed service: #{exposure[:name]}" unless node
          unless node.respond_to?(:exposed_port_no) && node.internal_url_scheme == "http"
            raise ArgumentError, "Invalid exposed resource type: #{node.name}; Istio exposure requires an HTTP service"
          end
          host = exposure[:root] ? domain : "#{project}-#{node.name}.#{environment}.#{declaration.base_domain}"
          validate_label!(host.split(".").first, "hostname")
          raise ArgumentError, "Invalid hostname length: #{host}" if host.bytesize > 253
          [node.name, host]
        end
        raise ArgumentError, "Invalid hostname length: #{domain}" if domain.bytesize > 253
      end

      def labels(service = nil)
        labels = {"app.kubernetes.io/managed-by" => "mobilis", "mobilis.io/project" => project,
                  "mobilis.io/environment" => environment}
        labels["mobilis.io/service"] = service if service
        labels
      end

      def self.validate_collisions!(universes)
        namespaces = universes.map(&:namespace)
        raise ArgumentError, "Kubernetes namespace collision" unless namespaces.uniq.size == namespaces.size
        hosts = universes.flat_map { |universe| [universe.domain, *universe.public_services.values.reject { |host| host == universe.domain }] }
        raise ArgumentError, "Kubernetes hostname collision" unless hosts.uniq.size == hosts.size
      end

      private

      def validate_label!(value, kind)
        raise ArgumentError, "Invalid Kubernetes #{kind} name: #{value.inspect}" unless Declaration.dns_label?(value)
      end
    end
  end
end
