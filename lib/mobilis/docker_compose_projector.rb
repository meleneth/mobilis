# frozen_string_literal: true

require "fileutils"

module Mobilis
  class DockerComposeProjector
    def self.port_skip
      10
    end

    def self.service_writers
      {
        kafka: Mobilis::OutputFiles::KafkaService,
        rails: Mobilis::OutputFiles::RailsService,
        redis: Mobilis::OutputFiles::RedisService,
        rack: Mobilis::OutputFiles::RackService,
        mysql: Mobilis::OutputFiles::MySQLService,
        postgresql: Mobilis::OutputFiles::PostgreSQLService
      }
    end

    def self.project_multi(project)
      project.projects.each do |service|
        writer = service_writers[service.type]
        writer&.new(service)&.write_to("compose")
      end
    end

    def self.project_base(target_environment, project)
      file = Mobilis::OutputFiles::ComposeBase.new(target_environment, project)
      file.write_to(".")
    end
  end
end
