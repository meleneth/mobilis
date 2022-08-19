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
