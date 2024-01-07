module Mobilis
  module Services
    class Directory
      def initialize
        @start_position = Dir.pwd
      end

      def chdir_start
        Dir.chdir @start_position
      end

      def chdir_project(project)
        Dir.chdir project_dir(project)
      end

      def chdir_rails_builder
        Dir.chdir rails_builder_dir
      end

      def mkdir_project(project)
        chdir_generate
      end

      def mkdir_project_data_dir(project)
        FileUtils.mkdir_p project_data_dir(project)
      end

      def mkdir_environment(environment)
        FileUtils.mkdir_p environment_dir(environment)
      end

      def chdir_environment(environment)
        Dir.chdir environment_dir(environment)
      end

      def mkdir_environment_datadir_forproject(environment, project)
        FileUtils.mkdir_p environment_datadir_forproject(environment, project)
      end

      def chdir_environment_datadir_forproject(environment, project)
        Dir.chdir environment_datadir_forproject(environment, project)
      end

      def environment_datadir_forproject(environment, project)
        File.join(environment_dir(environment), project.name.to_s)
      end

      def mkdir_generate
        if Dir.exist? generate_dir
          puts "Removing existing #{ generate_dir } directory"
          FileUtils.rm_rf(generate_dir)
        end
        Dir.mkdir generate_dir
      end

      def rm_localgems_project_gitdir(project)
        localgems_project_git_dir = File.join(localgems_dir, project.name, ".git")
        FileUtils.rm_rf localgems_project_git_dir
      end

      def mkdir_localgems
        chdir_generate
        Dir.mkdir "localgems" unless Dir.exist? "localgems"
      end

      def mkdir_rails_builder
        chdir_generate
        Dir.mkdir "rails-builder"
      end

      def chdir_generate
        Dir.chdir generate_dir
      end

      def chdir_localgems
        Dir.chdir localgems_dir
      end

      def project_dir(project)
        File.join(generate_dir, project.name)
      end

      def git_commit_all message
        my_git = git
        my_git.add
        my_git.commit(message)
      end

      private

      def git
        chdir_generate
        Git.open generate_dir
      end

      def generate_dir
        File.join(@start_position, "generate")
      end

      def environment_dir(environment)
        File.join(generate_dir, "data", environment.to_s)
      end

      def rails_builder_dir
        File.join(generate_dir, "rails-builder")
      end

      def localgems_dir
        File.join(generate_dir, "localgems")
      end

      def project_data_dir(project)
        File.join(generate_dir, "data", project.name)
      end
    end
  end
end
