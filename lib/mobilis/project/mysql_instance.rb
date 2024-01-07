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
        vars << "MYSQL_DATABASE=#{linked_to_rails_project.name}_production"
      end
      vars.concat [
        "MYSQL_USER=#{name}",
        "MYSQL_PASSWORD=#{name}_password",
        "MYSQL_RANDOM_ROOT_PASSWORD=true"
      ]
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
