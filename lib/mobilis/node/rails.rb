# frozen_string_literal: true

module Mobilis
  module Node
    # Base class for Ruby on Rails
    class Rails < Mobilis::Node::Ruby
      include Mobilis::PrettyPrint::PrettyPrintable

      ref_attr :primary_database

      attr_accessor :api_mode, :rspec_enabled, :factory_bot_enabled, :haml_enabled, :tailwind_enabled,
                    :uuid_primary_keys

      def rails_new_command
        command = [
          "rails new",
          name,
          "."
        ]
        command << "--api" if api_mode?
        command << "--skip-test" if rspec_enabled?
        if primary_database
          command << "--database=postgresql" if primary_database.class == Mobilis::Node::PostgreSQL
          command << "--database=mysql" if primary_database.class == Mobilis::Node::MySQL
        end
        command << "--css=tailwind" if tailwind_enabled?
        command.join(" ")
      end

      def use_rspec!
        @rspec_enabled = true
      end

      def use_uuid_primary_keys!
        write_file("db/migrate/20250713215716_enable_pgcrypto.rb", <<~PGCRYPTO)
          class EnablePgcrypto < ActiveRecord::Migration[8.0]
            def change
              enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
            end
          end
        PGCRYPTO
      end

      def install_factory_bot!
        @factory_bot_enabled = true
      end

      def use_haml!
        raise "Cannot enable Haml in API mode" if api_mode

        @haml_enabled = true
      end

      def use_tailwind!
        raise "Cannot enable Tailwind in API mode" if api_mode

        @tailwind_enabled = true
      end

      def use_api!
        raise "Cannot enable API mode when Haml is configured" if haml_enabled

        self.api_mode = true
      end

      def rspec_enabled?
        !!rspec_enabled
      end

      def factory_bot_enabled?
        !!factory_bot_enabled
      end

      def haml_enabled?
        !!haml_enabled
      end

      def api_mode?
        !!api_mode
      end

      def tailwind_enabled?
        !!tailwind_enabled
      end

      def add_rails_model(name, &block)
        new_model = Mobilis::Model::Rails::Model.new(name)
        new_model.instance_eval(&block) if block

        models << new_model
        new_model
      end

      def install_graphql!
        graphql_model = Mobilis::Model::Rails::GraphQL.new
        models << graphql_model
        graphql_model
      end

      def to_h
        super.merge({
                      api_mode: api_mode,
                      factory_bot_enabled: factory_bot_enabled,
                      haml_enabled: haml_enabled,
                      rspec_enabled: rspec_enabled,
                      tailwind_enabled: tailwind_enabled,
                      uuid_primary_keys: uuid_primary_keys
                    })
      end

      def self.from_h(hash)
        new(hash[:name]).tap do |obj|
          obj.api_mode = hash[:api_mode]
          obj.factory_bot_enabled = hash[:factory_bot_enabled]
          obj.haml_enabled = hash[:haml_enabled]
          obj.rspec_enabled = hash[:rspec_enabled]
          obj.tailwind_enabled = hash[:tailwind_enabled]
          obj.uuid_primary_keys = hash[:uuid_primary_keys]
        end
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "api_mode", api_mode
        dsl.instance_value "rspec_enabled", rspec_enabled
        dsl.instance_value "factory_bot_enabled", factory_bot_enabled
        dsl.instance_value "haml_enabled", haml_enabled
        dsl.instance_value "uuid_primary_keys", uuid_primary_keys
        dsl.child_object "primary_database", primary_database
      end
    end
  end
end
