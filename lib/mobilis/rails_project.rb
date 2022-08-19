# frozen_string_literal: true

require "mobilis/generic_project"
require "mobilis/os"

module Mobilis
class RailsProject < GenericProject

def child_env_vars
  [
    "#{ name.upcase }_HOST=#{ name }"
  ]
end

def controllers
  @data[:controllers]
end

def models
  @data[:models]
end

def database
  links.each do |link|
    project = @metaproject.project_by_name link
    return project if project.instance_of? Mobilis::PostgresqlInstance
    return project if project.instance_of? Mobilis::MysqlInstance
  end
  return nil
end

def toggle_rails_api_mode
  if options.include? :api then
    remove_rails_option :api
    add_rails_option :haml
  else
    add_rails_option :api
    remove_rails_option :haml
  end
end

def add_rails_option option
  remove_rails_option option
  options << option
end

def remove_rails_option option
  options.reject! {|x| x == option }
end

def add_controller name
  controller = {name: name, actions: []}
  @data[:controllers] << controller
  controller
end

def add_model name
  model = {name: name, fields: []}
  @data[:models] << model
  model
end

def rails_builder_image
  "#{ @metaproject.username }/rails-builder"
end

def rails_run_command command
  run_docker "run --rm -v #{ getwd }:/usr/src/app -w /usr/src/app #{ rails_builder_image } #{ command }"
end

def bundle_run command
  rails_run_command "./bundle_run.sh #{ command }"
end

def generate
  rails_run_command rails_new_command_line
  Dir.chdir name do
    git_commit_all "rails new"
    generate_bundle_run
    read_rails_master_key
    install_rspec if options.include? :rspec
    install_factory_bot if options.include? :factory_bot
    git_commit_all "add Gems"
    generate_Dockerfile
    generate_entrypoint_sh
    generate_build_sh
    git_commit_all "add Dockerfile and build script etc"
  end
end

def read_rails_master_key
  @data[:attributes][:rails_master_key] = File.read("config/master.key")
end

def rails_master_key
  @data[:attributes][:rails_master_key]
end

def generate_Dockerfile
  set_file_contents "Dockerfile", 'FROM ruby:latest
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client dos2unix
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
RUN bundle install
COPY . /myapp

# Add a script to be executed every time the container starts.
RUN chmod +x /myapp/entrypoint.sh
ENTRYPOINT ["/myapp/entrypoint.sh"]
EXPOSE 3000
RUN dos2unix /myapp/entrypoint.sh

# Configure the main process to run when running the image
CMD ["rails", "server", "-b", "0.0.0.0"]
'
end

def generate_entrypoint_sh
  set_file_contents "entrypoint.sh", "#!/bin/sh

# https://stackoverflow.com/a/38732187/1935918
set -e

if [ -f /app/tmp/pids/server.pid ]; then
  rm /app/tmp/pids/server.pid
fi

bundle exec rake db:migrate 2>/dev/null || bundle exec rake db:setup

exec bundle exec \"$@\"
"
end

def install_rspec
  Mobilis.logger.info "Installing rspec"
  append_line "Gemfile", 'gem "rspec-rails", group: [:development, :test]'
  bundle_run "rails generate rspec:install"
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
bundle install
$@
"
end

def install_super_diff
  append_line "Gemfile", "gem 'super_diff', group: [:development]"
  set_second_line 'spec/spec_helper.rb', 'require "super_diff/rspec"'
end

def rails_new_command_line
  pieces = ["bundle", "exec", "rails", "new", name, "."]
  pieces << "--api" if options.include? :api
  my_db = database
  if my_db then
    pieces << "--database=#{ my_db.type }"
  end
  if Mobilis::OS.linux?
    pieces << "-u #{ Process.uid }:#{ Process.gid }"
  end
  pieces.join " "
end

end
end
