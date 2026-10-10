# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

module Mobilis
  module Kubernetes
    # Adapts the realized graph and its generated files; Compose remains untouched.
    class Generator
      REGISTRY = "registry.deva.station"

      attr_reader :manifest, :root

      def initialize(manifest, root)
        @manifest = manifest
        @root = File.expand_path(root)
      end

      def write
        universes = manifest.kubernetes_universes
        universes.each do |universe|
          directory = File.join(root, "kubernetes", universe.environment)
          FileUtils.mkdir_p(directory)
          resources = resources_for(universe)
          File.write(File.join(directory, "resources.yml"), resources.map { |resource| ::YAML.dump(resource) }.join)
          File.write(File.join(directory, "builds.json"), JSON.pretty_generate(builds_for(universe)) + "\n")
          File.write(File.join(directory, "universe.json"), JSON.pretty_generate(
            project: universe.project, environment: universe.environment, namespace: universe.namespace,
            domain: universe.domain, public: universe.public_services
          ) + "\n")
        end
        File.write(File.join(root, "deploy-kubernetes"), deployment_helper)
        FileUtils.chmod("+x", File.join(root, "deploy-kubernetes"))
      end

      def builds_for(universe)
        universe.services.filter_map do |node|
          build = node.compose.clean_shrunk[:build]
          next unless build

          unsupported = build.keys - %i[context dockerfile args target labels]
          raise ArgumentError, "Unsupported Kubernetes build options for #{node.name}: #{unsupported}" unless unsupported.empty?
          labels = (build[:labels] || {}).merge(
            "org.opencontainers.image.vendor" => "Mobilis", "mobilis.project" => universe.project,
            "mobilis.environment" => universe.environment, "mobilis.service" => node.name
          )
          {service: node.name, image: image_for(universe, node), build: build.merge(labels: labels)}
        end
      end

      def image_for(universe, node)
        return node.compose_image unless node.compose_build_context

        # Devastation configures this registry and its CA for Docker and Kind.
        "#{REGISTRY}/#{universe.project}/#{node.name}:#{universe.environment}"
      end

      def resources_for(universe)
        resources = [resource(universe, "v1", "Namespace", universe.namespace,
          nil, namespaced: false)]
        resources.first["metadata"]["labels"]["istio-injection"] = "enabled"
        universe.services.each do |node|
          configs, volumes, mounts = configuration_for(universe, node)
          resources.concat(configs)
          resources.concat(alloy_rbac(universe, node)) if node.is_a?(Mobilis::Realized::Alloy)
          ports = ports_for(node)
          unless ports.empty?
            resources << resource(universe, "v1", "Service", node.name,
              {"type" => "ClusterIP", "selector" => universe.labels(node.name),
               "ports" => ports.map { |port| {"name" => port_name(node, port), "port" => port, "targetPort" => target_port_for(node, port)} }}, service: node.name)
          end
          container = {"name" => node.name, "image" => image_for(universe, node),
                       "imagePullPolicy" => node.compose_build_context ? "Always" : "IfNotPresent",
                       "env" => environment_for(node), "volumeMounts" => mounts,
                       "ports" => ports.map { |port| {"name" => port_name(node, port), "containerPort" => target_port_for(node, port)} }}
          compose = node.compose.clean_shrunk
          container["args"] = compose[:command] if compose[:command]
          container["command"] = compose[:entrypoint] if compose[:entrypoint]
          container["readinessProbe"] = {"tcpSocket" => {"port" => target_port_for(node, ports.first)}, "initialDelaySeconds" => 5} unless ports.empty?
          pod_spec = {"containers" => [container], "volumes" => volumes}
          groups = node.storage_requirements.filter_map { |storage| storage[:fs_group] }.uniq
          raise ArgumentError, "Conflicting storage groups for #{node.name}" if groups.size > 1
          pod_spec["securityContext"] = {"fsGroup" => groups.first} unless groups.empty?
          pod_spec["serviceAccountName"] = node.name if node.is_a?(Mobilis::Realized::Alloy)
          template = {"metadata" => {"labels" => universe.labels(node.name),
                                     "annotations" => {"mobilis.io/config-digest" => Digest::SHA256.hexdigest(JSON.generate(configs))}},
                      "spec" => pod_spec}
          resources << resource(universe, "apps/v1", "Deployment", node.name,
            {"replicas" => 1, "strategy" => {"type" => "Recreate"},
             "selector" => {"matchLabels" => universe.labels(node.name)}, "template" => template}, service: node.name)
        end
        resources.concat(istio_resources(universe))
        identities = resources.map { |object| [object["kind"], object.dig("metadata", "namespace"), object.dig("metadata", "name")] }
        raise ArgumentError, "Kubernetes resource identity collision" unless identities.uniq.size == identities.size
        resources
      end

      private

      def resource(universe, api, kind, name, spec, service: nil, namespaced: true)
        metadata = {"name" => name, "labels" => universe.labels(service)}
        metadata["namespace"] = universe.namespace if namespaced
        result = {"apiVersion" => api, "kind" => kind, "metadata" => metadata}
        result["spec"] = spec if spec
        result
      end

      def ports_for(node)
        ports = []
        ports << node.exposed_port_no if node.respond_to?(:exposed_port_no)
        ports << node.internal_port_no if node.respond_to?(:internal_port_no)
        ports.concat([4317, 4318, 9464]) if node.is_a?(Mobilis::Realized::OtelCollector)
        ports << 4317 if node.is_a?(Mobilis::Realized::Jaeger)
        ports.uniq
      end

      def port_name(node, port)
        return "grpc-otlp" if port == 4317 && [Mobilis::Realized::OtelCollector, Mobilis::Realized::Jaeger].any? { |klass| node.is_a?(klass) }
        return "tcp-#{port}" if node.is_a?(Mobilis::Realized::SQLDatabase)

        "http-#{port}"
      end

      def target_port_for(node, port)
        # Rails's generated image runs Thruster as an unprivileged user. Keep
        # the image entrypoint (including db:prepare) and internal Service URL.
        (node.is_a?(Mobilis::Realized::Rails) && port == 80) ? 8080 : port
      end

      def environment_for(node)
        values = node.compose_environment_override.vars_for_compose.to_h do |var|
          value = var.value
          if var.is_alias_only
            source = node.realized_env.all_envfile_vars.find { |candidate| candidate.envfile_name == var.envfile_name && !candidate.is_alias_only }
            raise ArgumentError, "Unresolved environment alias: #{var.envfile_name}" unless source
            value = source.value
          end
          [var.key, value.to_s]
        end
        if node.is_a?(Mobilis::Realized::Rails)
          master_key = File.join(root, node.name, "config", "master.key")
          values["RAILS_MASTER_KEY"] ||= File.read(master_key).strip if File.file?(master_key)
          values["RAILS_ENV"] = node.environment
          values["RAILS_LOG_TO_STDOUT"] = "true"
          values["RAILS_SERVE_STATIC_FILES"] = "true"
          values["THRUSTER_HTTP_PORT"] = "8080"
          collectors = node.connected_nodes(Mobilis::Realized::OtelCollector)
          raise ArgumentError, "Rails supports one OTEL Collector connection" if collectors.size > 1
          values["OTEL_EXPORTER_OTLP_ENDPOINT"] = collectors.first.internal_url if collectors.first
        end
        values.sort.map { |name, value| {"name" => name, "value" => value} }
      end

      def configuration_for(universe, node)
        data = {}
        volumes = []
        mounts = []
        configs = []
        node.storage_requirements.each do |storage|
          volume_name = "state-#{storage.fetch(:name)}"
          if universe.persistent_storage?
            claim_name = "#{universe.namespace}-#{node.name}-#{storage.fetch(:name)}"
            configs << resource(universe, "v1", "PersistentVolumeClaim", claim_name,
              {"accessModes" => ["ReadWriteOnce"], "resources" => {"requests" => {"storage" => storage.fetch(:size)}}}, service: node.name)
            volumes << {"name" => volume_name, "persistentVolumeClaim" => {"claimName" => claim_name}}
          else
            volumes << {"name" => volume_name, "emptyDir" => {}}
          end
          mounts << {"name" => volume_name, "mountPath" => storage.fetch(:path)}
        end
        # Declared state replaces Compose data binds. Configuration stays embedded.
        bindings = node.compose_volumes.data.dup
        bindings.delete("/var/run/docker.sock") if node.is_a?(Mobilis::Realized::Alloy)
        bindings.each_with_index do |(source, destination), index|
          destination = destination.delete_suffix(":ro")
          next if node.storage_requirements.any? { |storage| storage[:path] == destination }
          volume_name = "v#{index}"
          source_var = source.match(/\A\$\{([^}]+)\}\z/)
          if source_var
            var = node.realized_env.all_envfile_vars.find { |candidate| candidate.envfile_name == source_var[1] }
            raise ArgumentError, "Unknown volume variable: #{source}" unless var
            source = var.value.to_s
          end
          if source.start_with?("./data/")
            raise ArgumentError, "Undeclared Kubernetes state path for #{node.name}: #{destination}"
          end
          # Application source is already baked into its normal Mobilis build.
          next if node.compose_build_context && source == "./#{node.name}"
          path = File.expand_path(source, root)
          unless path.start_with?(root + "/") && File.exist?(path)
            raise ArgumentError, "Unsupported or missing Kubernetes configuration mount for #{node.name}: #{source}"
          end
          files = File.directory?(path) ? Dir.glob(File.join(path, "**", "*")).select { |file| File.file?(file) }.sort : [path]
          if files.empty?
            volumes << {"name" => volume_name, "emptyDir" => {}}
            mounts << {"name" => volume_name, "mountPath" => destination, "readOnly" => true}
            next
          end
          items = files.map.with_index do |file, file_index|
            key = "v#{index}-#{file_index}"
            content = File.read(file)
            content = alloy_config(universe, node) if node.is_a?(Mobilis::Realized::Alloy)
            data[key] = content
            {"key" => key, "path" => File.directory?(path) ? file.delete_prefix(path + "/") : File.basename(file)}
          end
          volumes << {"name" => volume_name, "configMap" => {"name" => node.name, "items" => items}}
          mount = {"name" => volume_name, "mountPath" => destination, "readOnly" => true}
          mount["subPath"] = File.basename(path) unless File.directory?(path)
          mounts << mount
        end
        unless data.empty?
          raise ArgumentError, "ConfigMap for #{node.name} exceeds 1 MiB" if data.values.sum(&:bytesize) > 1_000_000
          config = resource(universe, "v1", "ConfigMap", node.name, nil, service: node.name)
          config["data"] = data
          configs << config
        end
        [configs, volumes, mounts]
      end

      def alloy_config(universe, node)
        raise ArgumentError, "Alloy requires a connected Loki service" unless node.loki
        <<~ALLOY
          discovery.kubernetes "pods" {
            role = "pod"
            namespaces { names = ["#{universe.namespace}"] }
            selectors {
              role = "pod"
              label = "app.kubernetes.io/managed-by=mobilis"
            }
          }
          discovery.relabel "pods" {
            targets = discovery.kubernetes.pods.targets
            rule {
              source_labels = ["__meta_kubernetes_pod_label_mobilis_io_service"]
              target_label = "service"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_label_mobilis_io_service"]
              target_label = "service_name"
            }
            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              target_label = "namespace"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              target_label = "container"
            }
          }
          loki.source.kubernetes "pods" {
            targets = discovery.relabel.pods.output
            forward_to = [loki.write.default.receiver]
          }
          loki.write "default" {
            endpoint { url = "http://#{node.loki.name}:3100/loki/api/v1/push" }
          }
        ALLOY
      end

      def alloy_rbac(universe, node)
        account = resource(universe, "v1", "ServiceAccount", node.name, nil, service: node.name)
        role = resource(universe, "rbac.authorization.k8s.io/v1", "Role", node.name, nil, service: node.name)
        role["rules"] = [{"apiGroups" => [""], "resources" => ["pods", "pods/log"], "verbs" => ["get", "list", "watch"]}]
        binding = resource(universe, "rbac.authorization.k8s.io/v1", "RoleBinding", node.name, nil, service: node.name)
        binding["subjects"] = [{"kind" => "ServiceAccount", "name" => node.name, "namespace" => universe.namespace}]
        binding["roleRef"] = {"apiGroup" => "rbac.authorization.k8s.io", "kind" => "Role", "name" => node.name}
        [account, role, binding]
      end

      def istio_resources(universe)
        return [] if universe.public_services.empty?
        gateway = resource(universe, "networking.istio.io/v1", "Gateway", "mobilis", {
          "selector" => {"istio" => "ingressgateway"},
          "servers" => [{"port" => {"number" => 80, "name" => "http", "protocol" => "HTTP"},
                         "hosts" => universe.public_services.values.sort}]
        })
        routes = universe.public_services.sort.map do |name, host|
          node = universe.services.find { |service| service.name == name }
          resource(universe, "networking.istio.io/v1", "VirtualService", name, {
            "hosts" => [host], "gateways" => ["mobilis"],
            "http" => [{"route" => [{"destination" => {"host" => "#{name}.#{universe.namespace}.svc.cluster.local",
                                                       "port" => {"number" => node.exposed_port_no}}}]}]
          }, service: name)
        end
        [gateway, *routes]
      end

      def deployment_helper
        File.read(File.join(__dir__, "deploy.rb"))
      end
    end
  end
end
