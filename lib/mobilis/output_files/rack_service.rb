module Mobilis
  module OutputFiles
    class RackService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => project.docker_image_name,
          "ports" => ["${#{project.env_name}_EXTERNAL_PORT_NO}:${#{project.env_name}_INTERNAL_PORT_NO}"],
          "environment" => [],
          "build" => {
            "context" => "./#{project.name}"
          }
        }
      end
    end
  end
end
