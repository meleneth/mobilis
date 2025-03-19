module Mobilis
  module OutputFiles
    class RedisService < Mobilis::SingleServiceOutputFile
      def service_data
        {
          "image" => "redis:7.2.4-alpine",
          "restart" => "always",
          "command" => "redis-server --save 20 1 --loglevel warning --requirepass #{service.password}",
          "environment" => [],
          "ports" => ["${#{service.env_name}_EXTERNAL_PORT_NO}:${#{service.env_name}_INTERNAL_PORT_NO}"],
          "volumes" => [
            "#{service.data_dir}:/data"
          ]
        }
      end
    end
  end
end
