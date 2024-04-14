# frozen_string_literal: true

require 'debug'
require 'socket'

# rubocop:disable Metrics/ClassLength
module Mobilis
  class RailsProject < GenericProject
    attr_accessor :models

    def initialize(data, metaproject)
      super
      @models = []
    end

    def child_env_vars
      [
        "#{name.upcase}_HOST=#{name}"
      ]
    end

    def to_h
      my_models = models.collect(&:to_h)
      {
        name: @data[:name],
        type: :rails,
        controllers: [],
        models: my_models,
        options: @data[:options],
        attributes: {},
        links: @data[:links]
      }
    end

    def controllers
      @data[:controllers]
    end

    def name
      @data[:name]
    end

    def add_linked_postgresql_instance(dbname = nil)
      dbname ||= "#{name}db"
      postgresdb = @metaproject.add_postgresql_instance dbname
      new_links = links.clone
      new_links << postgresdb.name
      set_links new_links
      postgresdb
    end

    def add_linked_mysql_instance(dbname = nil)
      dbname ||= "#{name}db"
      mysqldb = @metaproject.add_mysql_instance dbname
      new_links = links.clone
      new_links << mysqldb.name
      set_links new_links
      mysqldb
    end

    def add_linked_redis_instance(dbname = nil)
      dbname ||= "#{name}db"
      redisdb = @metaproject.add_redis_instance dbname
      new_links = links.clone
      new_links << redisdb.name
      set_links new_links
      redisdb
    end

    def database
      links.each do |link|
        project = @metaproject.project_by_name link
        return project if project.instance_of? Mobilis::PostgresqlInstance
        return project if project.instance_of? Mobilis::MysqlInstance
      end
      nil
    end

    def toggle_rails_api_mode
      if options.include? :api
        remove_rails_option :api
        add_rails_option :haml
      else
        add_rails_option :api
        remove_rails_option :haml
      end
    end

    def toggle_uuid_primary_keys
      if options.include? :uuid_primary_keys
        remove_rails_option :uuid_primary_keys
      else
        add_rails_option :uuid_primary_keys
      end
    end

    def add_rails_option option
      remove_rails_option option
      options << option
    end

    def remove_rails_option option
      options.reject! { |x| x == option }
    end

    def add_controller name
      controller = {name: name, actions: []}
      @data[:controllers] << controller
      controller
    end

    def add_model name
      new_model = RailsModel.new(name, self)
      models << new_model
      new_model
    end

    def rails_builder_image
      "#{@metaproject.username}/rails-builder"
    end

    def rails_image
      "#{@metaproject.username}/#{name}"
    end

    def rails_run_command command
      run_docker "run --rm -v #{getwd}:/usr/src/app -w /usr/src/app #{rails_builder_image} #{command}"
    end

    def project_rails_run_command command, extra_args = ""
      run_docker "run --rm -v #{getwd}:/myapp -w /myapp #{extra_args} #{rails_image} #{command}"
    end

    def bundle_run command
      rails_run_command "./bundle_run.sh #{command}"
    end

    def project_bundle_run command, extra_args = ""
      project_rails_run_command "./bundle_run.sh #{command}", extra_args
    end

    def generate(directory_service:)
      directory_service.chdir_generate
      rails_run_command rails_new_command_line
      directory_service.chdir_project(self)
      Mobilis.logger.info "-- commiting rails new"
      directory_service.git_commit_all "#{name} - rails new"
      directory_service.chdir_project(self)
      Mobilis.logger.info "-- generating bundle run"
      generate_bundle_run
      Mobilis.logger.info "-- generating .gitignore"
      generate_gitignore
      Mobilis.logger.info "-- installing rspec (maybe)"
      install_rspec if options.include? :rspec
      Mobilis.logger.info "-- installing factory bot (maybe)"
      install_factory_bot if options.include? :factory_bot
      Mobilis.logger.info "-- git commit add Gems"
      directory_service.git_commit_all "#{name} - add Gems"
      directory_service.chdir_project(self)
      Mobilis.logger.info "-- generate_wait_until"
      generate_wait_until
      Mobilis.logger.info "-- generate_Dockerfile"
      generate_Dockerfile
      Mobilis.logger.info "-- generate_entrypoint_sh"
      generate_entrypoint_sh
      Mobilis.logger.info "-- generate_build_sh"
      generate_build_sh
      Mobilis.logger.info "-- git commit add Dockerfile and build script etc"
      directory_service.chdir_project(self)
      directory_service.git_commit_all "#{name} - add Dockerfile and build script etc"
      Mobilis.logger.info "-- reading rails master key"
      directory_service.chdir_project(self)
      read_rails_master_key
      patchup_master_key_env
      directory_service.git_commit_all "#{name} - set rails master key"
      directory_service.chdir_project(self)
      if models.length > 0
        generate_models directory_service
        directory_service.git_commit_all "#{name} - add Models"
        directory_service.chdir_project(self)
      end
    end

    def read_rails_master_key
      @data[:attributes][:rails_master_key] = File.read("config/master.key")
    end

    def rails_master_key
      @data[:attributes][:rails_master_key]
    end

    def patchup_master_key_env
      lines = FileLines.from_file(filename: "../compose/#{name}.yml")
      lines.gsub!(/- RAILS_MASTER_KEY=$/, "- RAILS_MASTER_KEY=#{rails_master_key}")
      lines.save
    end

    def generate_wait_until
      set_file_contents "wait-until", <<~WAITUNTIL
        #!/usr/bin/env bash
        # https://github.com/nickjj/wait-until under MIT license

        command="${1}"
        timeout="${2:-30}"

        i=1
        until eval "${command}"
        do
            ((i++))

            if [ "${i}" -gt "${timeout}" ]; then
                echo "command was never successful, aborting due to ${timeout}s timeout!"
                exit 1
            fi

            sleep 1
        done
      WAITUNTIL
    end

    def generate_models(directory_service)
      models.each do |model|
        directory_service.chdir_generate
        build_image(directory_service)
        directory_service.chdir_project(self)
        puts "Generating model #{model.name}"
        hostname = Socket.gethostname
        lines = FileLines.from_file(filename: "../compose/development.env")
        db = database
        external_db_port = lines.get_value("#{db.name}_EXTERNAL_PORT_NO")
        project_bundle_run model.line, "-e DATABASE_URL=postgres://#{db.name}-development-user:#{db.name}-development-password@#{hostname}:#{external_db_port}/#{db.name}-development"
      end
    end

    def build_image(directory_service)
      directory_service.chdir_generate
      comment_out_cmd(directory_service)
      run_docker "compose -f compose-development.yml build #{name}"
      uncomment_cmd(directory_service)
    end

    def comment_out_cmd(directory_service)
      directory_service.chdir_generate
      lines = FileLines.from_file(filename: "./#{name}/Dockerfile")
      lines.gsub! 'CMD ["rails", "server", "-b", "0.0.0.0"]', '# CMD ["rails", "server", "-b", "0.0.0.0"]'
      lines.gsub! 'ENTRYPOINT ["/myapp/entrypoint.sh"]', '# ENTRYPOINT ["/myapp/entrypoint.sh"]'
      lines.save
    end

    def uncomment_cmd(directory_service)
      directory_service.chdir_generate
      lines = FileLines.from_file(filename: "./#{name}/Dockerfile")
      lines.gsub! '# CMD ["rails", "server", "-b", "0.0.0.0"]', 'CMD ["rails", "server", "-b", "0.0.0.0"]'
      lines.gsub! '# ENTRYPOINT ["/myapp/entrypoint.sh"]', 'ENTRYPOINT ["/myapp/entrypoint.sh"]'
      lines.save
    end

    def generate_Dockerfile
      set_file_contents "Dockerfile", <<~DOCKER_END
        FROM ruby:latest
        RUN apt-get update -qq && apt-get install -y nodejs postgresql-client default-mysql-client dos2unix

        WORKDIR /myapp
        COPY #{_p("Gemfile")} /myapp/Gemfile
        COPY #{_p("Gemfile.lock")} /myapp/Gemfile.lock
        RUN bundle config set --local path 'vendor/bundle'
        RUN bundle install

        COPY #{_p(".")} /myapp
        COPY --chmod=0755 #{_p("wait-until")} /myapp/wait-until
        COPY --chmod=0755 #{_p("entrypoint.sh")} /myapp/entrypoint.sh

        # Add a script to be executed every time the container starts.
        ENTRYPOINT ["/myapp/entrypoint.sh"]
        EXPOSE 3000
        RUN dos2unix /myapp/entrypoint.sh

        # Configure the main process to run when running the image
        CMD ["rails", "server", "-b", "0.0.0.0"]
      DOCKER_END
    end

    def generate_gitignore
      set_file_contents ".gitignore", <<~GITIGNORE_END
        *.rbc
        capybara-*.html
        .rspec
        /db/*.sqlite3
        /db/*.sqlite3-journal
        /db/*.sqlite3-[0-9]*
        /public/system
        /coverage/
        /spec/tmp
        *.orig
        rerun.txt
        pickle-email-*.html
        
        # Ignore all logfiles and tempfiles.
        /log/*
        /tmp/*
        !/log/.keep
        !/tmp/.keep

        data
        
        # TODO Comment out this rule if you are OK with secrets being uploaded to the repo
        config/initializers/secret_token.rb
        config/master.key
        
        # Only include if you have production secrets in this file, which is no longer a Rails default
        # config/secrets.yml
        
        # dotenv, dotenv-rails
        # TODO Comment out these rules if environment variables can be committed
        .env
        .env*.local
        
        ## Environment normalization:
        /.bundle
        /vendor/bundle
        
        # these should all be checked in to normalize the environment:
        # Gemfile.lock, .ruby-version, .ruby-gemset
        
        # unless supporting rvm < 1.11.0 or doing something fancy, ignore this:
        .rvmrc
        
        # if using bower-rails ignore default bower_components path bower.json files
        /vendor/assets/bower_components
        *.bowerrc
        bower.json
        
        # Ignore pow environment settings
        .powenv
        
        # Ignore Byebug command history file.
        .byebug_history
        
        # Ignore node_modules
        node_modules/
        
        # Ignore precompiled javascript packs
        /public/packs
        /public/packs-test
        /public/assets
        
        # Ignore yarn files
        /yarn-error.log
        yarn-debug.log*
        .yarn-integrity
        
        # Ignore uploaded files in development
        /storage/*
        !/storage/.keep
        /public/uploads
        GITIGNORE_END
    end

    def generate_entrypoint_sh
      set_file_contents "entrypoint.sh", <<~ENTRYPOINT_SH
        #!/bin/sh

        # https://stackoverflow.com/a/38732187/1935918
        set -e

        if [ -f /app/tmp/pids/server.pid ]; then
          rm /app/tmp/pids/server.pid
        fi
        #{wait_until_line}
        bundle exec rake db:migrate 2>/dev/null || bundle exec rake db:setup

        exec bundle exec "$@"
      ENTRYPOINT_SH
    end

    def wait_until_line
      # TODO FIXME
      if database.instance_of? Mobilis::PostgresqlInstance
        return <<~POSTGRES_LINE
          /myapp/wait-until "psql $DATABASE_URL -c 'select 1'"
        POSTGRES_LINE
      end

      # instance_of? is a code smell - maybe this should be database.wait_until_line ?
      if database.instance_of? Mobilis::MysqlInstance
        <<~MYSQL_LINE
          /myapp/wait-until "mysql -D #{name}_production -h #{database.name} -u #{database.username} -p#{database.password} -e 'select 1'"
        MYSQL_LINE
      end
    end

    def install_rspec
      Mobilis.logger.info "Installing rspec"
      append_line "Gemfile", 'gem "rspec-rails", group: [:development, :test]'
      bundle_run "rails generate rspec:install"
    end

    def bundle_install
      Mobilis.logger.info "Running bundle install"
      bundle_run "bundle install"
    end

    def install_factory_bot
      Mobilis.logger.info "Installing FactoryBot"
      append_line "Gemfile", "gem 'factory_bot_rails'"
      set_file_contents "spec/support/factory_bot.rb", "RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
"
    end

    def generate_bundle_run
      Mobilis.logger.info "Installing bundle_run.sh"

      set_file_contents "bundle_run.sh", "#!/bin/bash
set -euo pipefail
bundle install --path vendor/bundle
$@
"
      FileUtils.chmod("+x", "bundle_run.sh")
    end

    def install_super_diff
      append_line "Gemfile", "gem 'super_diff', group: [:development]"
      set_second_line "spec/spec_helper.rb", 'require "super_diff/rspec"'
    end

    def rails_new_command_line
      pieces = ["bundle", "exec", "rails", "new", name, ".", "--skip-bundle", "--skip-git"]
      pieces << "--api" if options.include? :api
      my_db = database
      if my_db
        pieces << "--database=#{my_db.type}"
      end
      pieces.join " "
    end

    def global_env_vars(environment)
      {
        "#{env_name}_EXTERNAL_PORT_NO": 'AUTO_EXTERNAL_PORT',
        "#{env_name}_INTERNAL_PORT_NO": 3000
      }
    end
  end
end
