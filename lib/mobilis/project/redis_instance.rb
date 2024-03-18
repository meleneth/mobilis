# frozen_string_literal: true

module Mobilis
  class RedisInstance < GenericProject
    def generate
      FileUtils.mkdir_p data_dir
    end

    def child_env_vars
      [
        "REDIS_HOST_#{env_name}=#{name}",
        "REDIS_PORT_#{env_name}=6379",
        "REDIS_PASSWORD_#{env_name}=#{password}"
      ]
    end

    def env_name
      name.upcase
    end

    def data_dir
      "./data/#{name}"
    end

    def has_local_build
      false
    end

    def username
      name
    end

    def password
      "#{name}_password"
    end

    def is_datastore_project?
      true
    end

    def global_env_vars(environment)
      {
        "#{env_name}_EXTERNAL_PORT_NO": 'AUTO_EXTERNAL_PORT',
        "#{env_name}_INTERNAL_PORT_NO": 9292
      }
    end
  end
end
