# frozen_string_literal: true

module Mobilis
  class PostgresqlInstance < GenericProject
    def generate(directory_service:)
    end

    def child_env_vars
      []
    end

    def user_id_arg
      "#{Process.uid}:#{Process.gid}"
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

    def db_name(environment)
      "#{name}-#{environment}"
    end

    def global_env_vars(environment)
      vars = {
        "#{env_name}_INTERNAL_PORT_NO": 5432,
        "#{env_name}_EXTERNAL_PORT_NO": "AUTO_EXTERNAL_PORT",
        "#{env_name}_POSTGRES_DB": db_name(environment),
        "#{env_name}_POSTGRES_USER": username(environment),
        "#{env_name}_POSTGRES_PASSWORD": password(environment),
        "#{env_name}_POSTGRES_DATA": "./data/#{environment}/#{name}",
        "#{env_name}_POSTGRES_URL": url(environment)
      }
      if linked_to_rails_project
        vars["#{linked_to_rails_project.env_name}_DATABASE_URL"] = url(environment)
      end
      vars
    end

    def env_var
      "POSTGRES_DB"
    end

    def env_name
      name.upcase.tr("-_", "")
    end

    def data_dir
      "./data/#{name}"
    end

    def has_local_build
      false
    end

    def password(environment)
      "#{name}-#{environment}-password"
    end

    def url(environment)
      "postgres://#{username(environment)}:#{password(environment)}@#{name}:5432/#{name}-#{environment}"
    end

    def username(environment)
      "#{name}-#{environment}-user"
    end

    def is_datastore_project?
      true
    end
  end
end
