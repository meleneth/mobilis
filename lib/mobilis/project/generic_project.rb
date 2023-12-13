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

    attr_reader :metaproject

    def_delegators :@metaproject, :starting_port, :port_gap, :username, :getwd

    def initialize data, metaproject
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

    def env_vars
      []
    end

    def links_to_actually_link
      children.filter { |l| !l.instance_of? Mobilis::LocalgemProject }
              .map { |l| l.name }
    end

    # projects who are linked to us
    def children
      links.map { |name| @metaproject.project_by_name name }
    end

    # projects we are linked to
    def parents
      @metaproject.projects.filter { |l| l.links.include? name }
    end

    def linked_to_rails_project
      parents.find { |l| l.instance_of? Mobilis::RailsProject }
    end

    def linked_to_localgem_project
      linked_localgem_projects.length > 0
    end

    def linked_localgem_projects
      children.find_all { |l| l.instance_of? Mobilis::LocalgemProject }
    end

    def display
      ap @data
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

    def set_links new_links
      @data[:links] = new_links
    end

    def to_json
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


    # generate the local file structure to support the project
    def generate
      FileUtils.mkdir_p name
    end
  end
end
