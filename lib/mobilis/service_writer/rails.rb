module Mobilis
  module ServiceWriter
    class Rails < Mobilis::Base::ServiceWriter
      def write
        Dir.chdir("..")
        rails_builder.container_run("rails new #{@realized_node.name} .")
        Dir.chdir(@realized_node.name)
        rails_builder.container_run("bundle add pg")
        FileUtils.rm_rf(".git")
        @manifest.commit_all("add Rails project #{@realized_node.name}")
      end

      def rails_builder
        @manifest.plugin_for Mobilis::Plugin::RailsBuilder
      end

      def write_compose_file
        service_details = {}
        service_details[:image] = "#{username}/#{@realized_node.name}"
        service_details[:build] = { context: "./#{realized_node.name}" }
        service_details[:environment] = @realized_node.env_vars.map(&:docker_repr)
        service = {}
        service[@realized_node.name] = service_details
        services = { services: service }

        directory_service.chdir_compose
        File.write("#{realized_node.name}.yml", YAML.dump(Mobilis::YAML.deep_stringify_keys(services)))
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
