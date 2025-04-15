# frozen_string_literal: true

module Mobilis
  module Plugin
    class RailsBuilder < Mobilis::Base::Plugin
      extend Forwardable

      def_delegators :@manifest, :directory_service

      def hook_before_services_written
        directory_service.mkdir_rails_builder
        directory_service.chdir_rails_builder
        create_rails_builder_dockerfile
        create_rails_builder_gemfile
        build_rails_builder
        directory_service.chdir_generate
      end

      def rails_builder_image
        "#{username}/rails-builder"
      end

      def username
        ENV.fetch("USER", ENV.fetch("USERNAME", ""))
      end

      def oblivious_run_command(command)
        # fixme
        # Mobilis.logger.info "$ #{command.join " "}"
        puts "-> Running --> #{command}"
        system command
      end

      def run_docker(cmd)
        oblivious_run_command "docker #{cmd}"
      end

      def build_rails_builder
        run_docker "build -t #{rails_builder_image} --build-arg USER_ID=#{Process.uid} --build-arg GROUP_ID=#{Process.gid} ."
      end

      def set_file_contents(filename, contents)
        File.open(filename, "w") do |f|
          f.write contents
        end
      end

      def create_rails_builder_dockerfile
        set_file_contents "Dockerfile", <<~EOF
          FROM ruby:latest
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
          RUN gem update bundle
          RUN gem update --system

          COPY Gemfile .
          RUN bundle install

          ARG USER_ID
          ARG GROUP_ID
          RUN addgroup --gid $GROUP_ID rubyuser
          RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID rubyuser
          USER rubyuser
        EOF
        # it makes no sense that these values were hardcoded at 200 when I was passing
        # in the id's, why did that happen?
        # I assume it's because at some point something didn't work
        # so here's me taking notes trying to figure it out
        # using the args seems to have helped things a bit, but it didn't just work
        # Dir.chdir is conflicting with itself all over the place, time to stop using the block
        # form and get more in-control over where the CWD is
      end

      def create_rails_builder_gemfile
        set_file_contents "Gemfile", <<~EOF
          source "https://rubygems.org"
          # FIXME
          #git_source(:github) { |repo| "https://github.com/repo.git" }

          gem "rails"
          gem "sqlite3"
          gem "puma"
          gem "jbuilder"
          gem "redis"
          gem "kredis"
          gem "bcrypt"
          gem "bootsnap", require: false
          gem "image_processing"
          gem "rack-cors"
          gem "pg"
          gem "mysql2"
          gem "minitest"

          group :development, :test do
            gem "debug", platforms: %i[ mri mingw x64_mingw ]
          end

          group :development do
            gem "spring"
          end

          gem "rspec-rails", group: [:development, :test]
        EOF
      end
    end
  end
end
