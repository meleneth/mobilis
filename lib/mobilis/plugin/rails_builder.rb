# frozen_string_literal: true

module Mobilis
  module Plugin
    class RailsBuilder < Mobilis::Base::Plugin
      def create_builder_images
        directory_service.mkdir_rails_builder
        directory_service.chdir_rails_builder
        create_rails_builder_dockerfile
        @manifest.commit_all("Add rails builder Dockerfile")
        build_rails_builder
        directory_service.chdir_generate
      end

      def rails_builder_image
        "#{username}/rails-builder"
      end

      def oblivious_run_command(command)
        puts "-> Running --> #{command}"
        system(command) || raise("Command failed (#{$?.exitstatus || 1}): #{command}")
      end

      def run_docker(cmd)
        oblivious_run_command "docker #{cmd}"
      end

      def build_rails_builder
        run_docker "build -t #{rails_builder_image} --build-arg USER_ID=#{host_user_id} --build-arg GROUP_ID=#{host_group_id} ."
      end

      def container_run(command)
        run_docker "run --rm -v #{getwd}:/usr/src/app -w /usr/src/app #{rails_builder_image} #{command}"
      end

      def getwd
        Dir.pwd
      end

      def host_user_id
        return 1000 if Gem.win_platform?
        return 1000 if Process.uid.zero?

        Process.uid
      end

      def host_group_id
        return 1000 if Gem.win_platform?
        return 1000 if Process.gid.zero?

        Process.gid
      end

      def set_file_contents(filename, contents)
        File.open(filename, "w") do |f|
          f.write contents
        end
      end

      def create_rails_builder_dockerfile
        set_file_contents "Dockerfile", <<~EOF
          FROM #{Mobilis::ContainerVersions::RUBY}
          RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
          # Common dependencies
          RUN apt-get update -qq \\
            && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \\
              build-essential \\
              gnupg2 \\
              curl \\
              less \\
              git \\
              nodejs \\
              postgresql-client \\
            && apt-get clean \\
            && rm -rf /var/cache/apt/archives/* \\
            && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \\
            && truncate -s 0 /var/log/*log

          RUN gem update --system
          RUN gem update bundler
          RUN gem install rails pg mysql2 minitest rspec-rails puma jbuilder sqlite3 redis kredis bcrypt image_processing graphql

          ENV BUNDLE_PATH=/tmp/bundle \
          BUNDLE_USER_HOME=/tmp/bundle \
          BUNDLE_APP_CONFIG=/tmp/bundle/config
          ENV PATH="/tmp/bundle/bin:$PATH"

          ARG USER_ID
          ARG GROUP_ID
          RUN addgroup --gid $GROUP_ID rubyuser
          RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID rubyuser
          RUN mkdir -p /tmp/bundle && chown -R rubyuser:rubyuser /tmp/bundle
          RUN mkdir -p /app && chown -R rubyuser:rubyuser /app
          WORKDIR /app
          USER rubyuser
          RUN bundle config set --global path /tmp/bundle
          RUN bundle config set --global bin /tmp/bundle/bin
        EOF
        # it makes no sense that these values were hardcoded at 200 when I was passing
        # in the id's, why did that happen?
        # I assume it's because at some point something didn't work
        # so here's me taking notes trying to figure it out
        # using the args seems to have helped things a bit, but it didn't just work
        # Dir.chdir is conflicting with itself all over the place, time to stop using the block
        # form and get more in-control over where the CWD is
      end
    end
  end
end
