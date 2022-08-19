# frozen_string_literal: true

require "mobilis/generic_project"

module Mobilis
class RedisInstance < GenericProject

def generate
  FileUtils.mkdir_p data_dir
end

def child_env_vars
  [
    "REDIS_HOST=#{ name }",
    "REDIS_PORT=6379",
    "REDIS_PASSWORD=#{ password }"
  ]
end

def data_dir
  "./data/#{ name }"
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

end
end
