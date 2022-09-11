# frozen_string_literal: true

require "mobilis/generic_project"

module Mobilis
class PostgresqlInstance < GenericProject

def generate
  FileUtils.mkdir_p data_dir
end

def child_env_vars
  [ ]
end

def env_vars
  vars = []
  if linked_to_rails_project
    vars << "POSTGRES_DB=#{ linked_to_rails_project.name }_production"
  end
  vars.concat [
   "POSTGRES_USER=#{ name }",
   "POSTGRES_PASSWORD=#{ password }"
  ]
end

def data_dir
  "./data/#{ name }"
end

def has_local_build
  false
end

def url
  "postgres://#{ username }:#{ password }@#{ name }:5432/"
end

def username
  name
end

def password
  "#{name}_password"
end


end
end
