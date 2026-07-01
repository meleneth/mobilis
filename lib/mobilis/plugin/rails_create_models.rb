# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin creates rails models defined on rails services
    class RailsCreateModels < Mobilis::Base::Plugin
      extend Forwardable

      def hook_create_rails_models
        manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_node.primary_database
          next unless realized_env.is_test?

          directory_service.chdir_generate
          realized_node.each_model_of_type(Mobilis::Model::Rails::Model) do |model|
            next unless model.generate_model?

            Mobilis::Util.run_command(
              [
                "./dc_test",
                "run",
                "--rm",
                "--entrypoint",
                '""',
                realized_node.name,
                "./bin/rails",
                "generate",
                "model",
                model.name,
                *model.field_args
              ]
            )
            commit_all("#{realized_node.name} create model #{model.name}")
          end
        end
      end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
