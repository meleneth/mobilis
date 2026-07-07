# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists to deal with rails prod needing 3 extra db isntances by default
    class RailsDBFanoutRealizedNode < Mobilis::Base::RealizedNodePlugin
      extend Forwardable

      def_delegators :realized_node, :compose_overrides, :primary_database, :compose_env_vars
      attr_reader :extra_env_db_urls

      def create_additional_services
        wireup_variant(realized_env, realized_node, "cache")
        wireup_variant(realized_env, realized_node, "cable")
        wireup_variant(realized_env, realized_node, "queue")
      end

      def hook_after_services_written
        # TODO: FIXME kinda lazy to do rspec here
        return unless realized_node.config_node.rspec_enabled?

        directory_service.chdir_project(realized_node)
        rails_builder.container_run("bundle add rspec-rails --group \"development,test\"")
        rails_builder.container_run("/bin/bash -lc \"bundle install && bundle exec rails generate rspec:install\"")
        commit_all("#{realized_node.name} - rpsec install")
      end

      def rails_builder
        builder = manifest.plugin_for Mobilis::Plugin::RailsBuilder
        raise "RailsBuilder plugin is required to install Rails database fanout support" unless builder.is_a?(Mobilis::Plugin::RailsBuilder)

        builder
      end

      def wireup_variant(realized_env, realized_node, name)
        db = realized_node.primary_database
        raise "Rails database fanout requires a primary database" unless db

        db_name = "#{db.name}-#{name}"

        new_db = case db
                 when Mobilis::Realized::PostgreSQL
                   new_db_node = Mobilis::Node::PostgreSQL.new(db_name)
                   Mobilis::Realized::PostgreSQL.new(realized_env, new_db_node)
                 when Mobilis::Realized::MySQL
                   new_db_node = Mobilis::Node::MySQL.new(db_name)
                   Mobilis::Realized::MySQL.new(realized_env, new_db_node)
                 else
                   raise "Unsupported Rails database fanout source #{db.class}"
        end
        realized_env << new_db
        db_env_db_url = new_db.env_db_url
        envfile_name = db_env_db_url.envfile_name
        raise "Rails database fanout URL for #{new_db.name} is missing an env file name" unless envfile_name

        realized_node.add_compose_aliased_var("#{name}_DATABASE_URL",
                                              envfile_name,
                                              db_env_db_url.value,
                                              override: true)
        realized_node.register_depends_on(new_db, override: true)
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
