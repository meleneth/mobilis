# frozen_string_literal: true

module Mobilis
  class LocalgemProject < GenericProject
    def name
      @data[:name]
    end

    def global_env_vars(environment)
      {
      }
    end

    def generate(directory_service:)
      directory_service.mkdir_localgems
      directory_service.chdir_localgems
      run_command "bundle gem #{name}", true
      directory_service.chdir_localgems
      directory_service.rm_localgems_project_gitdir(self)

      directory_service.git_commit_all "Generated localgem #{name}"
    end
  end
end
