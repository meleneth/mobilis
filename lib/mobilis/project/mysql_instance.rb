# frozen_string_literal: true

module Mobilis
  class MysqlInstance < GenericProject
    def generate
      FileUtils.mkdir_p data_dir
    end

    def child_env_vars
      []
    end

    def env_vars
      vars = []
      if linked_to_rails_project
        vars << "MYSQL_DATABASE=${#{env_name}_MYSQL_DATABASE}"
      end
      vars.concat [
        "MYSQL_USER=${#{env_name}_MYSQL_USER}",
        "MYSQL_PASSWORD=${#{env_name}_MYSQL_PASSWORD}",
        "MYSQL_RANDOM_ROOT_PASSWORD=true"
      ]
    end

    def global_env_vars(environment)
      {
        "#{env_name}_MYSQL_USER": name,
        "#{env_name}_MYSQL_PASSWORD": password,
        "#{env_name}_MYSQL_DATA": "./data/#{environment}/#{name}",
        "#{env_name}_MYSQL_URL": url
      }
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
      "mysql2://#{username}:#{password}@#{name}:3306/?pool=5"
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
