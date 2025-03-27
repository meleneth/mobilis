# frozen_string_literal: true

module Mobilis
  ##
  # base class for projects.
  # Child classes should override
  # generate
  # and as needed
  # child_env_vars
  module Project
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
        [] # : Array[String]
      end

      def each_project_for_environment(environment = nil)
        return enum_for(:each_project_for_environment) unless block_given?

        yield self
      end

      def env_vars
        [] # : Array[String]
      end

      # all caps env name
      def env_name
        name.upcase.tr("-", "_")
      end

      def links_to_actually_link(environment = nil)
        each_child(environment)
          .reject { |l| l.instance_of?(Mobilis::Project::LocalgemProject) }
          .map(&:name)
          .to_a
      end

      def each_child(environment = nil)
        return enum_for(:each_child) unless block_given?

        links.each do |link|
          yield @metaproject.project_by_name(link)
        end
      end

      def service_writer
        nil
      end

      def each_parent(environment = nil)
        return enum_for(:each_parent) unless block_given?

        @metaproject.each_project_for_environment(environment) do |project|
          yield project if project.links.include? name
        end
      end

      def linked_to_rails_project?
        each_linked_to_rails_project.any?
      end

      def each_linked_to_rails_project
        return enum_for(:each_linked_to_rails_project) unless block_given?

        each_parent do |project|
          yield project if project.instance_of? Mobilis::Project::RailsProject
        end
      end

      def linked_to_localgem_project?
        each_linked_to_localgem_project.any?
      end

      def each_linked_to_localgem_project
        return enum_for(:each_linked_to_localgem_project) unless block_given?

        each_child do |child|
          yield child if child.instance_of? Mobilis::Project::LocalgemProject
        end
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
        return path unless linked_to_localgem_project?

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
      def generate(directory_service:)
        FileUtils.mkdir_p name
      end

      def global_env_vars(_environment)
        {}
      end

      def is_service_project?
        true
      end
    end
  end
end
