module Mobilis
  module OutputFiles
    class RackService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => service.docker_image_name,
          "ports" => ["${#{service.env_name}_EXTERNAL_PORT_NO}:${#{service.env_name}_INTERNAL_PORT_NO}"],
          "environment" => [],
          "build" => {
            "context" => "./#{service.name}"
          }
        }
      end
    end
  end
end
