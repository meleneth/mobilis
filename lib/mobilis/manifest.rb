# frozen_string_literal: true

require "fileutils"
require "mobilis/generation/execution"

module Mobilis
  # here it is, the main class that actually orchestratest the entire
  # dance of file creation.
  class Manifest
    include Mobilis::PrettyPrint::PrettyPrintable
    attr_reader :system, :realized_envs, :directory_service, :git_repo, :plugins
    attr_writer :git_repo

    def initialize(system, suppress_plugins: false, directory_service: Mobilis::Services::Directory.new)
      @system = system
      generated_broker_names = system.config_nodes.values.flat_map do |node|
        next [] unless node.is_a?(Mobilis::Node::Kafka)

        ["#{node.name}-topics", *(2..node.brokers).map { |index| "#{node.name}-#{index}" }]
      end
      declared_names = system.config_nodes.values.map(&:name)
      duplicates = generated_broker_names.select do |name|
        declared_names.include?(name) || generated_broker_names.count(name) > 1
      end.uniq
      raise ArgumentError, "Kafka broker service names collide: #{duplicates.join(', ')}" unless duplicates.empty?
      if system.kubernetes_deployment && system.config_nodes.values.any? { |node| node.is_a?(Mobilis::Node::Kafka) && node.brokers > 1 }
        raise ArgumentError, "Multi-broker Kafka generation currently supports Docker Compose, not Kubernetes"
      end
      @directory_service = directory_service
      port_allocator = Mobilis::RealizedEnv::PortAllocator.new(system.starting_port, reservation_count: environments.length)
      @realized_envs = environments.map do |env|
        Mobilis::RealizedEnv.new(system, env, port_allocator: port_allocator)
      end
      kubernetes_universes if system.kubernetes_deployment

      return if suppress_plugins

      setup_plugins
      run_plugin_hooks :generate_per_node_plugins
      run_plugin_hooks :create_additional_services
    end

    def add_plugin(plugin)
      @plugins << plugin
    end

    def realized_production_env
      @realized_envs.find(&:is_production?) || raise("No production environment for manifest")
    end

    def realized_env(target_env)
      @realized_envs.each do |env|
        return env if env.to_s == target_env.to_s
      end
      raise "No such environment #{target_env} for manifest"
    end

    def materialize
      run_generation(Mobilis::Generation::Native.new(self))
    end

    def materialize_browser(on_checkpoint:)
      capabilities = Mobilis::Browser::Capabilities.project(system)
      unless capabilities.browser_generation
        raise ArgumentError, "Browser generation cannot run host-dependent models or configuration: #{capabilities.reason}"
      end

      run_generation(Mobilis::Generation::Browser.new(self, on_checkpoint: on_checkpoint))
    end

    # One ordered generation plan. Adapters only supply environmental
    # capabilities; writers, plugins and commit boundaries remain Mobilis's.
    def run_generation(execution)
      raise ArgumentError, "Generation already active" if @generation_execution

      @generation_execution = execution
      directory_service.chdir_start
      directory_service.mkdir_generate
      directory_service.mkdir_compose
      directory_service.chdir_generate
      write_gitignore
      write_readme
      execution.prepare_repository
      commit_all("Basic project files")
      execution.create_builder_images
      run_plugin_hooks :hook_before_services_written
      emit_all_services
      run_plugin_hooks :hook_after_services_written
      emit_compose_wrappers
      emit_env_files
      write_overrides_for(:test)
      write_overrides_for(:development)
      write_overrides_for(:production)
      commit_all("Compose overrides")
      write_commands_file
      commit_all("Commands file")
      write_mobilis_system
      commit_all("Mobilis system config")
      write_dc_helpers
      commit_all("docker compose helper scripts")
      commit_all("devcontainer configuration") if write_devcontainer
      execution.after_helpers
      write_kubernetes if system.kubernetes_deployment
      execution.finish
      directory_service.chdir_generate
      Dir.pwd
    ensure
      directory_service.chdir_start if execution.browser?
      @generation_execution = nil
    end

    # Write every artifact that Mobilis can produce without invoking Git,
    # Docker, or generated-project commands. This is the generation path used
    # by constrained runtimes such as ruby.wasm; it deliberately uses the same
    # realized nodes, plugins, service writers, and compose emitters as the
    # native materializer.
    def materialize_static
      capabilities = Mobilis::Browser::Capabilities.project(system)
      unless capabilities.browser_generation
        raise ArgumentError, "This project requires local generation. #{capabilities.reason}"
      end

      @static_generation = true
      directory_service.chdir_start
      directory_service.mkdir_generate
      directory_service.mkdir_compose
      directory_service.chdir_generate
      write_gitignore
      write_readme
      run_plugin_hooks :create_builder_images
      run_plugin_hooks :hook_before_services_written
      emit_all_services
      run_plugin_hooks :hook_after_services_written
      emit_compose_wrappers
      emit_env_files
      write_overrides_for(:test)
      write_overrides_for(:development)
      write_overrides_for(:production)
      write_commands_file
      write_mobilis_system
      write_dc_helpers
      write_devcontainer
      run_plugin_hooks :hook_after_dc_helpers
      write_kubernetes if system.kubernetes_deployment
      directory_service.chdir_generate
      Dir.pwd
    ensure
      directory_service.chdir_start
      @static_generation = false
    end

    def kubernetes_universes
      return [] unless system.kubernetes_deployment

      universes = realized_envs.map { |env| Mobilis::Kubernetes::Universe.new(env, system.kubernetes_deployment) }
      Mobilis::Kubernetes::Universe.validate_collisions!(universes)
      universes
    end

    def write_kubernetes
      directory_service.chdir_generate
      Mobilis::Kubernetes::Generator.new(self, Dir.pwd).write
      commit_all("Kubernetes workloads and Istio routes")
    end

    def write_mobilis_system
      directory_service.chdir_generate
      File.open("mobilis-system.json", "w") do |f|
        f.write(system.to_json)
      end
    end

    def write_commands_file
      directory_service.chdir_generate
      File.open("commands.txt", "w") do |f|
        f.write("Production:\n")
        f.write("HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose --env-file production.env -f production-compose.yml -f production-overrides.yml config\n")
        f.write("Development:\n")
        f.write("HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose --env-file development.env -f development-compose.yml -f development-overrides.yml config\n")
        f.write("Test:\n")
        f.write("HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose --env-file test.env -f test-compose.yml -f test-overrides.yml config\n")
      end
    end

    def write_dc_helpers
      write_dc_helper("dc_test", "test")
      write_dc_helper("dc_dev", "development")
      write_dc_helper("dc_prod", "production")
    end

    def write_devcontainer
      directory_service.chdir_generate
      rails_services = devcontainer_rails_services
      return false if rails_services.empty?

      FileUtils.mkdir_p(".devcontainer")

      first_service = rails_services.first
      File.write(".devcontainer/devcontainer.json",
                 "#{JSON.pretty_generate(devcontainer_config(first_service, "development"))}\n")
      Mobilis::YAMLWriter.write_yaml(".devcontainer/devcontainer-overrides.yml",
                                     devcontainer_overrides(rails_services))

      rails_services.each do |service|
        FileUtils.mkdir_p(".devcontainer/#{service.name}-test")
        File.write(".devcontainer/#{service.name}-test/devcontainer.json",
                   "#{JSON.pretty_generate(devcontainer_config(service, "test", nested: true))}\n")
      end
      true
    end

    def devcontainer_rails_services
      realized_production_env.realized_nodes
                             .filter_map do |node|
        node if node.is_a?(Mobilis::Realized::Rails)
      end
    end

    def devcontainer_config(service, env, nested: false)
      # @type var config: Hash[String, untyped]
      config = {
        "name" => "#{service.name}-#{env}",
        "initializeCommand" => devcontainer_initialize_command(env),
        "dockerComposeFile" => devcontainer_compose_files(env, nested: nested),
        "service" => service.name,
        "workspaceFolder" => "/rails",
        "shutdownAction" => "stopCompose"
      }
      config["customizations"] = devcontainer_customizations if env == "test"
      config
    end

    def devcontainer_initialize_command(env)
      env_file = env == "test" ? "test.env" : "development.env"
      compose_file = env == "test" ? "test-compose.yml" : "development-compose.yml"
      overrides_file = env == "test" ? "test-overrides.yml" : "development-overrides.yml"
      resolved_file = env == "test" ? "dc_test.resolved.yml" : "dc_dev.resolved.yml"

      "docker compose --env-file #{env_file} -f #{compose_file} -f #{overrides_file} config > .devcontainer/#{resolved_file}"
    end

    def devcontainer_compose_files(env, nested:)
      resolved_file = env == "test" ? "dc_test.resolved.yml" : "dc_dev.resolved.yml"
      prefix = nested ? "../" : ""
      [
        "#{prefix}#{resolved_file}",
        "#{prefix}devcontainer-overrides.yml"
      ]
    end

    def devcontainer_overrides(services)
      {
        "services" => services.to_h do |service|
          [
            service.name,
            {
            "volumes" => [
              "../#{service.name}:/rails:cached"
            ],
            "tmpfs" => [
              "/rails/tmp/pids"
            ]
            }
          ]
        end
      }
    end

    def devcontainer_customizations
      {
        "vscode" => {
          "extensions" => [
            "Shopify.ruby-lsp"
          ],
          "settings" => {
            "rubyLsp.formatter" => "auto",
            "editor.formatOnSave" => true,
            "files.trimTrailingWhitespace" => true,
            "files.insertFinalNewline" => true
          }
        }
      }
    end

    def write_dc_helper(filename, env_name)
      File.write(filename, <<~HERE)
        #!/usr/bin/env bash
        set -e

        ENV_FILE="#{env_name}.env"
        COMPOSE_FILE="compose/#{env_name}-compose.yml"

        ## Load .env only if it exists
        #[ -f "$ENV_FILE" ] && export $(grep -v '^#' "$ENV_FILE" | xargs)

        # Inject UID/GID for Unix-like systems
        if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
        	export HOST_UID=$(id -u)
        	export HOST_GID=$(id -g)
        fi

        exec docker compose --env-file #{env_name}.env -f #{env_name}-compose.yml -f #{env_name}-overrides.yml "$@"
      HERE
      FileUtils.chmod("+x", filename)
    end

    def write_gitignore
      File.open(".gitignore", "w") do |f|
        f.write("data\n")
      end
    end

    def write_readme
      File.write("README.md", <<~MARKDOWN)
        # #{system.meta_project_name}

        Generated by Mobilis.

        ## Docker Compose Helpers

        - `./dc_test` runs the test environment.
        - `./dc_dev` runs the development environment.
        - `./dc_prod` runs the production environment.

        ## Host ports

        Starting port: `#{system.starting_port}`. Each generated host port is
        reserved in increments of ten. Internal container ports are unchanged.

        #{realized_envs.flat_map { |env| env.realized_nodes.flat_map { |node| node.envfile_vars.data.filter_map { |var| "- #{env.environment} `#{var.envfile_name}=#{var.value}`" if var.envfile_name&.end_with?("_PORT") } } }.join("\n")}

        #{grafana_readme_section}
        #{pgadmin_readme_section}
        #{kubernetes_readme_section}
      MARKDOWN
    end

    def kubernetes_readme_section
      return "" unless system.kubernetes_deployment

      hosts = kubernetes_universes.flat_map do |universe|
        universe.public_services.map { |name, host| "- #{universe.environment} #{name}: `http://#{host}`" }
      end.join("\n")
      <<~MARKDOWN
        ## Kubernetes / Istio

        Run `./deploy-kubernetes dev` (or `test`, `prod`) to build using the generated
        Dockerfiles, push to the Devastation registry, and deploy through Istio.
        The default context is `kind-devastation`; `MOBILIS_KUBE_CONTEXT` selects another context.
        Istio and the registry must already be installed. DNS and edge TLS belong to Devastation.

        #{hosts}

        Only the listed services have external routes. All workload Services are ClusterIP.
        Resources and build plans are in `kubernetes/{dev,test,prod}/`.
        Declared state uses PVCs in dev/prod and emptyDir in test, at the same container paths.
        PVCs use the cluster's default StorageClass. Preserve the PVC and its underlying storage.
        Apply independently with `kubectl apply -f kubernetes/dev/resources.yml` after publishing images.
        Resources use `mobilis.io/project=#{system.meta_project_name}` and `mobilis.io/environment` labels.
        Mobilis generates once; subsequent lifecycle and artifact changes belong to standard tooling.
        Generated configuration is mounted as files. No Kubernetes Secrets are generated.
      MARKDOWN
    end

    def grafana_readme_section
      return "" unless realized_production_env.realized_nodes.any? { |node| node.is_a?(Mobilis::Realized::Grafana) }

      <<~MARKDOWN
        ## Grafana

        Grafana is generated with a non-default admin password so the demo does not force an initial password change.

        - Username: `#{Mobilis::Realized::Grafana::ADMIN_USER}`
        - Password: `#{Mobilis::Realized::Grafana::ADMIN_PASSWORD}`

        The password is for generated local/demo environments only. Change it before using the generated project for anything sensitive.
      MARKDOWN
    end

    def pgadmin_readme_section
      return "" unless realized_production_env.realized_nodes.any? { |node| node.is_a?(Mobilis::Realized::Pgadmin) }

      <<~MARKDOWN
        ## pgAdmin

        pgAdmin is generated with local/demo admin credentials and preloaded PostgreSQL server definitions.

        - Username: `#{Mobilis::Realized::Pgadmin::ADMIN_EMAIL}`
        - Password: `#{Mobilis::Realized::Pgadmin::ADMIN_PASSWORD}`

        The password is for generated local/demo environments only. Change it before using the generated project for anything sensitive.
      MARKDOWN
    end

    def commit_all(message)
      return if @static_generation

      if @generation_execution
        @generation_execution.commit(message)
      else
        # Retain the legacy direct-call behavior for writers/tests that
        # already installed a native Git repository.
        require "git"
        puts " -- git commit: #{message} --"
        @git_repo.add(all: true)
        @git_repo.commit("[mobilis] #{message}")
      end
    end

    def setup_plugins
      @plugins = realized_envs
                 .flat_map(&:required_plugins)
                 .uniq
                 .map { |klass| klass.new(self) }
      @plugins << Mobilis::Plugin::WriteFiles.new(self)
      @plugins << Mobilis::Plugin::WriteScripts.new(self)
      @plugins << Mobilis::Plugin::Plugerator.new(self)
      @plugins << Mobilis::Plugin::RunCommands.new(self)
      @plugins << Mobilis::Plugin::EnvVars.new(self)
      @plugins << Mobilis::Plugin::FilteredActiveResource.new(self)
      @plugins
    end

    def run_plugin_hooks(hook)
      @plugins.dup.each do |plugin|
        plugin.send(hook)
      end
    end

    def run_node_hooks(hook, &block)
      realized_envs.each do |realized_env|
        realized_env.dup.each_node do |realized_node|
          if block
            realized_node.send(hook, &block)
          else
            realized_node.send(hook)
          end
        end
      end
    end

    def plugin_for(klass)
      @plugins.each do |plugin|
        return plugin if plugin.is_a? klass
      end
      nil
    end

    def each_node_of_type(klass, &block)
      return enum_for(:each_node_of_type, klass) unless block

      @realized_envs.each do |realized_env|
        realized_env.each_node_of_type(klass, &block)
      end
    end

    def ppx_fields(dsl)
      dsl.child_object "system", @system
      dsl.child_object "directory_service", @directory_service
      @realized_envs.each do |realized_env|
        dsl.child_object realized_env.environment, realized_env
      end
    end

    def username
      ENV.fetch("USER", ENV.fetch("USERNAME", ""))
    end

    def overrides_for(realized_env)
      overrides = AutoVivify.new
      realized_env.realized_nodes.each do |node|
        overrides[:services][node.name].merge! node.compose_overrides
      end
      overrides.clean_shrunk
    end

    private

    def environments
      %i[test development production].map do |env|
        Mobilis::ExecutionEnvironment.new env
      end
    end

    def emit_env_files
      directory_service.chdir_generate

      @realized_envs.each do |realized_env|
        # @type var vars_for_env: Hash[String, untyped]
        vars_for_env = {}

        realized_env.all_envfile_vars do |emit_var|
          envfile_name = emit_var.envfile_name
          next unless envfile_name

          if vars_for_env.key? envfile_name
            unless emit_var.value == vars_for_env[envfile_name]
              raise "Different values for #{envfile_name} - #{emit_var.value} vs #{vars_for_env[envfile_name]}"
            end
          else
            vars_for_env[envfile_name] = emit_var.value
          end
        end
        lines = vars_for_env.sort.map { |k, v| "#{k}=#{v}" }

        File.write("#{realized_env.environment}.env", "#{lines.join("\n")}\n")
      end
      commit_all "env files"
    end

    def emit_compose_wrappers
      directory_service.chdir_generate
      @realized_envs.each do |realized_env|
        # @type var details: Hash[String, untyped]
        details = {}
        details["name"] = "#{system.meta_project_name}-#{realized_env}"
        # @type var includes: Array[Hash[String, String]]
        includes = []
        realized_env.realized_nodes.each do |node|
          # @type var node_details: Hash[String, String]
          node_details = {}
          node_details["path"] = "./compose/#{node.name}.yml"
          node_details["project_directory"] = "./"
          node_details["env_file"] = "./#{realized_env.environment}.env"
          includes << node_details
        end
        details["include"] = includes
        Mobilis::YAMLWriter.write_yaml("#{realized_env}-compose.yml", details)
      end
      commit_all("compose wrappers")
    end

    def emit_all_services
      # @type var service_dirs_written: Hash[String, bool]
      service_dirs_written = {}
      @realized_envs.each do |realized_env|
        realized_env.realized_nodes.each do |realized_node|
          name = realized_node.name

          if realized_node.has_service_dir
            next if service_dirs_written[name]

            directory_service.mkdir_project(realized_node)
            directory_service.chdir_project(realized_node)
            writer = realized_node.service_writer.new(self, realized_env, realized_node)
            if @generation_execution
              @generation_execution.write_service(writer, realized_node)
            else
              writer.write
            end
            writer.write_image_ownership
            directory_service.chdir_generate
            service_dirs_written[name] = true
          end
          directory_service.chdir_generate
          if realized_node.has_data_volume
            directory_service.mkdir_environment_datadir_forproject(realized_env.environment,
                                                                   realized_node)
          end
          Mobilis::YAMLWriter.write_yaml("compose/#{realized_node.name}.yml",
                                         realized_node.service_wrapped_compose)
        end
      end
    end

    def write_overrides_for(raw_env)
      overrides = overrides_for(realized_env(raw_env))
      return if overrides.nil?

      Mobilis::YAMLWriter.write_yaml("#{raw_env}-overrides.yml", overrides)
    end
  end
end
