# frozen_string_literal: true

module Mobilis
  module OutputFiles
    class Overrides < Mobilis::OutputFile
      attr_reader :environment, :project_config

      def initialize(environment, project_config)
        super("#{environment}-overrides.yml")
        @environment = environment
        @project_config = project_config
      end

      def render
        services = {} # : hash[String, untyped]
        project_config.each_project_for_environment(@environment) do |project|
          next unless project.respond_to? :production_links_overrides

          project_links = project.production_links_overrides
          services[project.name][:links] = project_links if project_links
        end
        YAML.dump(info)
      end
    end
  end
end
