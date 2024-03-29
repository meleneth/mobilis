require "fileutils"

module Mobilis
  class DockerComposeProjector
    def self.port_skip
      10
    end

    def self.project project
      projector = DockerComposeProjector.new project

      services = {}
      project.projects.each_with_index do |service, index|
        service_definition = projector.send "#{service.type}_service", service
        if service_definition
          if service.linked_to_localgem_project
            service_definition["build"] = {
              "context" => "./",
              "dockerfile" => "./#{service.name}/Dockerfile"
            }
          end
          services[service.name] = service_definition
          if service.links.count > 0
            services[service.name]["links"] = service.links_to_actually_link.map(&:to_s)
            services[service.name]["depends_on"] = service.links_to_actually_link.map(&:to_s)
            service.links.each do |link|
              linked_service = project.project_by_name link
              linked_service.child_env_vars.each do |var|
                services[service.name]["environment"] << var
              end
            end
          end
        end
      end
      {"version" => "3.8", "services" => services}
    end

    def rails_service service
      attributes = @project.attributes
      keyname = "#{service.name}_internal_port_no".to_sym
      vars = []
      vars << "RAILS_ENV=production"
      vars << "RAILS_MASTER_KEY=#{service.rails_master_key}"
      vars << "RAILS_MIN_THREADS=5"
      vars << "RAILS_MAX_THREADS=5"

      database = service.database
      if database
        vars << "#{database.env_var}=#{database.url}"
      end

      # vars << "NEW_RELIC_APP_NAME=#{ service.name }"
      # vars << "NEW_RELIC_LICENSE_KEY=#{ attributes[:new_relic_license_key] }"
      # vars << "NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true"
      {
        "image" => service.docker_image_name,
        "ports" => ["#{attributes[keyname]}:3000"],
        "environment" => vars,
        "build" => {
          "context" => "./#{service.name}"
        }
      }
    end

    def rack_service service
      attributes = @project.attributes
      keyname = "#{service.name}_internal_port_no".to_sym
      {
        "image" => service.docker_image_name,
        "ports" => ["#{attributes[keyname]}:9292"],
        "environment" => [],
        "build" => {
          "context" => "./#{service.name}"
        }
      }
    end

    def postgresql_service service
      attributes = @project.attributes
      keyname = "#{service.name}_internal_port_no".to_sym
      {
        "image" => "postgres:15.2-alpine",
        "restart" => "always",
        "environment" => service.env_vars,
        "ports" => ["#{attributes[keyname]}:5432"],
        "volumes" => [
          "#{service.data_dir}:/var/lib/postgresql/data"
        ]
      }
    end

    def mysql_service service
      attributes = @project.attributes
      keyname = "#{service.name}_internal_port_no".to_sym
      {
        "image" => "mysql:debian",
        "restart" => "always",
        "environment" => service.env_vars,
        "ports" => ["#{attributes[keyname]}:3306"],
        "volumes" => [
          "#{service.data_dir}:/var/lib/mysql"
        ]
      }
    end

    def redis_service service
      attributes = @project.attributes
      port_key = "#{service.name}_internal_port_no".to_sym
      {
        "image" => "redis:7.0.11-alpine",
        "restart" => "always",
        "command" => "redis-server --save 20 1 --loglevel warning --requirepass #{service.password}",
        "environment" => [],
        "ports" => ["#{attributes[port_key]}:6379"],
        "volumes" => [
          "#{service.data_dir}:/data"
        ]
      }
    end

    def localgem_service service
      # nothing here, because it doesn't integrate directly
    end

    def get_cwd_path
      f = Dir.getwd
      if f[1] == ":"
        f[1] = f[0].downcase
        f[0] = "/"
      end
      f
    end

    def initialize project
      @project = project
    end
  end
end
