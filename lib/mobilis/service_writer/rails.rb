module Mobilis
  module ServiceWriter
    class Rails < Mobilis::Base::ServiceWriter
      def write
        Dir.chdir("..")
        rails_builder.container_run(realized_node.rails_new_command)
        Dir.chdir(@realized_node.name)
        FileUtils.rm_rf(".git")
        normalize_rails_runtime
        @manifest.commit_all("add Rails project #{@realized_node.name}")
      end

      def rails_builder
        builder = @manifest.plugin_for Mobilis::Plugin::RailsBuilder
        raise "RailsBuilder plugin is required to generate Rails services" unless builder.is_a?(Mobilis::Plugin::RailsBuilder)

        builder
      end

      def normalize_rails_runtime
        version = ruby_version
        image = ruby_image

        File.write(".ruby-version", "ruby-#{version}\n")

        Mobilis::FileLines.edit("Gemfile") do
          replace_line(/^ruby\s+["']/) { %(ruby "#{version}") }
        end

        Mobilis::FileLines.edit("Dockerfile") do
          replace_line(/^ARG RUBY_VERSION=/) { "ARG RUBY_VERSION=#{version}" }
          replace_line(%r{^FROM registry\.docker\.com/library/ruby:\$RUBY_VERSION-slim as base$}) do
            "FROM #{image} as base"
          end
          insert_before(/^COPY Gemfile Gemfile\.lock \.\//,
                        "RUN mkdir -p \"${BUNDLE_PATH}\" && chmod -R 777 \"${BUNDLE_PATH}\"")
        end

        File.binwrite("bin/docker-entrypoint", <<~BASH)
          #!/bin/bash -e

          # If running the rails server then create or migrate existing database.
          # Docker DNS and healthcheck state can lag briefly on Windows, so retry startup preparation.
          if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
            for attempt in 1 2 3 4 5; do
              ./bin/rails db:prepare && break
              status=$?
              if [ "$attempt" = "5" ]; then
                exit "$status"
              fi
              sleep 2
            done
          fi

          exec "${@}"
        BASH
      end

      def ruby_image
        Mobilis::ContainerVersions::RUBY
      end

      def ruby_version
        ruby_image.split(":", 2).fetch(1).split("-", 2).first
      end

      def write_compose_file
        service_details = {} #: Hash[Symbol, untyped]
        service_details[:image] = "#{username}/#{@realized_node.name}"
        service_details[:build] = { context: "./#{realized_node.name}" }
        service_details[:environment] = @realized_node.env_vars_for_compose_environment.map(&:compose_repr)
        service = {} #: Hash[String, Hash[Symbol, untyped]]
        service[@realized_node.name] = service_details
        services = { services: service }

        directory_service.chdir_compose
        File.write("#{realized_node.name}.yml", ::YAML.dump(Mobilis::YAML.deep_stringify_keys(services)))
        commit_all("Compose for #{realized_node.name}")

        #---
        # services:
        #  user-service:
        #    image: meleneth/user-service
        #    ports:
        #    - "${USER_SERVICE_EXTERNAL_PORT_NO}:${USER_SERVICE_INTERNAL_PORT_NO}"
        #    environment:
        #    - RAILS_ENV=production
        #    - RAILS_MASTER_KEY=1964398f8e61c3992e058751dc5e257c
        #    - RAILS_MIN_THREADS=5
        #    - RAILS_MAX_THREADS=5
        #    - DATABASE_URL=${USER_SERVICE_DATABASE_URL}
        #    build:
        #      context: "./user-service"
        #    links:
        #    - userdb
        #    depends_on:
        #    - userdb
      end
    end
  end
end
