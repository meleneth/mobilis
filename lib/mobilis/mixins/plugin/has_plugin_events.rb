module Mobilis
  module Mixins
    module Plugin
      module HasPluginEvents
        def create_additional_services
        end

        def create_builder_images
        end

        def generate_per_node_plugins
        end

        def hook_before_services_written
        end

        def hook_after_services_written
        end

        def hook_after_dc_helpers
        end

        def hook_create_rails_models
        end
      end
    end
  end
end
