# frozen_string_literal: true

module Mobilis
  ##
  # base class for projects.
  # Child classes should override
  # generate
  # and as needed
  # child_env_vars
  class GenericProject
    include ActionsProjectsTake
    extend Forwardable

    attr_reader :metaproject, :data

    def_delegators :@metaproject, :starting_port, :port_gap, :username, :getwd

    def initialize(data, metaproject)
      @data = data
      data[:attributes] = {} unless data[:attributes]
      data[:options] = [] unless data[:options]
      data[:links] = [] unless data[:links]
      @metaproject = metaproject
    end

    ##
    # environment env vars added to linked child services
    def child_env_vars
      []
    end

    def each_project_for_environment(environment = nil)
      yield self
    end

    def env_vars
      []
    end

    # all caps env name
    def env_name
      name.upcase.tr("-", "_")
    end

    def links_to_actually_link(environment = nil)
      children(environment).filter { |l| !l.instance_of? Mobilis::LocalgemProject }
                           .map { |l| l.name }
    end

    # projects who are linked to us
    def children(environment = nil)
      links.map { |name| @metaproject.project_by_name name }
    end

    # projects we are linked to
    def parents(environment = nil)
      @metaproject.each_project_for_environment(environment) do |project|
        yield project if project.links.include? name
      end
    end

    def linked_to_rails_project
      parents do |project|
        if project.instance_of? Mobilis::RailsProject
          yield project
          return
        end
      end
    end

    def linked_to_localgem_project
      linked_localgem_projects.length.positive?
    end

    def linked_localgem_projects
      children.find_all { |l| l.instance_of? Mobilis::LocalgemProject }
    end

    def display
      ap to_h
    end

    def name
      @data[:name]
    end

    def options
      @data[:options]
    end

    def type
      @data[:type]
    end

    def links
      @data[:links]
    end

    def set_links(new_links)
      @data[:links] = new_links
    end

    def add_link(new_link)
      @data[:links] << new_link
    end

    def _p(path)
      return path unless linked_to_localgem_project

      "./#{name}/#{path}"
    end

    def to_h
      @data
    end

    def docker_image_name
      "#{@metaproject.username}/#{name}"
    end

    def generate_build_sh
      write_file "build.sh" do |f|
        f.write "docker build -t #{docker_image_name} ."
      end
    end

    def is_datastore_project?
      false
    end

    def compose_filename
      "./compose/#{name}.yml"
    end

    # generate the local file structure to support the project
    def generate
      FileUtils.mkdir_p name
    end

    def global_env_vars(_environment)
      {}
    end

    def is_service_project
      true
    end
  end
end
