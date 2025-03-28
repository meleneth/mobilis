module Mobilis
  module OutputFiles
    class RedisService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "redis:7.2.4-alpine",
          "restart" => "always",
          "command" => "redis-server --save 20 1 --loglevel warning --requirepass #{project.password}",
          "environment" => [],
          "ports" => ["${#{project.env_name}_EXTERNAL_PORT_NO}:${#{project.env_name}_INTERNAL_PORT_NO}"],
          "volumes" => [
            "#{project.data_dir}:/data"
          ]
        }
      end
    end
  end
end
