# frozen_string_literal: true

module Mobilis
  class RackProject < GenericProject
    def name
      @data[:name]
    end

    def generate(directory_service:)
      directory_service.mkdir_project(self)
      directory_service.chdir_project(self)
      generate_config_ru
      generate_Gemfile
      generate_Gemfile_lock
      generate_Dockerfile
    end

    def global_env_vars(environment)
      {
      }
    end

    def generate_config_ru
      set_file_contents "config.ru", <<~CONFIG_RU
        # config.ru
        app = Proc.new {
          [
            200,
            { "content-type" => "text/html" },
            ["Hello, Rack"]
          ]
        }
        run app
      CONFIG_RU
    end

    def generate_Gemfile
      set_file_contents "Gemfile", <<~GEMFILE
        # frozen_string_literal: true

        source "https://rubygems.org"

        # gem "rails"

        gem "rack", "= 3.0.2"

        gem "rackup", "~> 0.2.2"
      GEMFILE
    end

    def generate_Gemfile_lock
      set_file_contents "Gemfile.lock", <<~GEMFILE_LOCK
        GEM
          remote: https://rubygems.org/
          specs:
            rack (3.0.2)
            rackup (0.2.2)
              rack (>= 3.0.2)
              webrick
            webrick (1.7.0)

        PLATFORMS
          x64-mingw-ucrt

        DEPENDENCIES
          rack (= 3.0.2)
          rackup (~> 0.2.2)

        BUNDLED WITH
           2.3.16
      GEMFILE_LOCK
    end

    def generate_Dockerfile
      set_file_contents "Dockerfile", get_Dockerfile
    end

    def localgem_prefix
      return "" unless linked_to_localgem_project

      "#{name}/"
    end

    def get_Dockerfile
      if linked_to_localgem_project
        get_Dockerfile_with_localgems
      else
        get_Dockerfile_default
      end
    end

    def get_Dockerfile_default
      <<~DOCKER_END
        FROM ruby:latest
        RUN apt-get update -qq && apt-get install -y postgresql-client
        WORKDIR /myapp
        COPY Gemfile /myapp/Gemfile
        COPY Gemfile.lock /myapp/Gemfile.lock
        RUN bundle install
        COPY . /myapp
        # Add a script to be executed every time the container starts.
        ENTRYPOINT ["rackup", "-o", "#{name}"]
        EXPOSE 9292
      DOCKER_END
    end

    def get_Dockerfile_with_localgems
      localgem_lines = []
      linked_localgem_projects.each do |p|
        localgem_lines << "COPY localgems/#{p.name} /myapp/localgems/#{p.name}"
        localgem_lines << "WORKDIR /myapp/localgems/#{p.name}"
        localgem_lines << "RUN bundle install"
        localgem_lines << "RUN rake install"
      end

      <<~DOCKER_END
        FROM ruby:latest as gem-cache
        RUN gem install bundler:2.4.12
        RUN mkdir -p /myapp/localgems
        #{localgem_lines.join "\n"}
        FROM gem-cache as final
        COPY --from=gem-cache /usr/local/bundle /usr/local/bundle
        RUN apt-get update -qq && apt-get install -y postgresql-client
        WORKDIR /myapp
        COPY #{localgem_prefix}Gemfile /myapp/Gemfile
        COPY #{localgem_prefix}Gemfile.lock /myapp/Gemfile.lock
        RUN bundle install
        COPY #{localgem_prefix}. /myapp
        # Add a script to be executed every time the container starts.
        ENTRYPOINT ["rackup", "-o", "#{name}"]
        EXPOSE 9292
      DOCKER_END
    end
  end
end
