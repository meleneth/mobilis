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

      def mkdir_generate
        if Dir.exist? generate_dir
          puts "Removing existing #{ generate_dir } directory"
          FileUtils.rm_rf(generate_dir)
        end
        Dir.mkdir generate_dir
      end

      def mkdir_rails_builder
        chdir_generate
        Dir.mkdir "rails-builder"
      end

      def chdir_generate
        Dir.chdir generate_dir
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

      def rails_builder_dir
        File.join(generate_dir, "rails-builder")
      end
    end
  end
end