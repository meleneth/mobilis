module Mobilis
  class SingleServiceOutputFile < OutputFile
    attr_reader :project

    def initialize(project)
      super(project.compose_filename)
      @project = project
    end

    def metaproject
      @project.metaproject
    end

    def render
      YAML.dump({ "services" => { project.name => render_data } })
    end

    def render_data
      service_definition = service_data
      if project.linked_to_localgem_project?
        service_definition["build"] = {
          "context" => "./",
          "dockerfile" => "./#{project.name}/Dockerfile"
        }
      end
      return service_definition unless project.links.count.positive?

      service_definition["links"] = project.links_to_actually_link.map(&:to_s)
      service_definition["depends_on"] = project.links_to_actually_link.map(&:to_s)
      project.links.each do |link|
        linked_service = metaproject.project_by_name link
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
