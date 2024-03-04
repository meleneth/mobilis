# frozen_string_literal: true

module Mobilis
  class PostgresqlInstance < GenericProject
    def generate(directory_service:)
    end

    def child_env_vars
      []
    end

    def env_vars
      vars = []
      if linked_to_rails_project
        vars << "POSTGRES_DB=${#{env_name}_POSTGRES_DB}"
      end
      vars.concat [
        "POSTGRES_USER=${#{env_name}_POSTGRES_USER}",
        "POSTGRES_PASSWORD=${#{env_name}_POSTGRES_PASSWORD}"
      ]
    end

    def global_env_vars(environment)
      {
        "#{env_name}_INTERNAL_PORT_NO": 5432,
        "#{env_name}_EXTERNAL_PORT_NO": 9999,
        "#{env_name}_POSTGRES_DB": "#{name}_#{environment}",
        "#{env_name}_POSTGRES_USER": name,
        "#{env_name}_POSTGRES_PASSWORD": password,
        "#{env_name}_POSTGRES_DATA": "./data/#{environment}/#{name}",
        "#{env_name}_POSTGRES_URL": url
      }
    end

    def env_var
      "POSTGRES_DB"
    end

    def env_name
      name.upcase.tr("-", "_")
    end

    def data_dir
      "./data/#{name}"
    end

    def has_local_build
      false
    end

    def url
      "postgres://#{username}:#{password}@#{name}:5432/"
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
  end
end
