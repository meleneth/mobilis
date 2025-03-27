module Mobilis
  class SingleServiceOutputFile < OutputFile
    attr_reader :service

    def initialize(service)
      super(service.compose_filename)
      @service = service
    end

    def project
      @service.metaproject
    end

    def render
      YAML.dump({ "services" => { service.name => render_data } })
    end

    def render_data
      service_definition = service_data
      if service.linked_to_localgem_project?
        service_definition["build"] = {
          "context" => "./",
          "dockerfile" => "./#{service.name}/Dockerfile"
        }
      end
      return service_definition unless service.links.count.positive?

      service_definition["links"] = service.links_to_actually_link.map(&:to_s)
      service_definition["depends_on"] = service.links_to_actually_link.map(&:to_s)
      service.links.each do |link|
        linked_service = project.project_by_name link
        linked_service.child_env_vars.each do |var|
          service_definition["environment"] << var
        end
      end
      service_definition
    end

    def service_data
      raise "Subclass must implement"
    end
  end
end
