# frozen_string_literal: true

module Mobilis
  module Mixins
    module RealizedNode
      # Mixin to add volume mount support to RealizedNode.
      module HasVolumes
        # Logical state paths, independent of Compose's host bind mounts.
        # Kubernetes chooses the backing storage from the realized environment.
        def storage_requirements
          @storage_requirements ||= []
        end

        def declare_storage(name, path, size: "1Gi", fs_group: nil)
          unless name.match?(/\A[a-z][a-z0-9-]*[a-z0-9]\z|\A[a-z]\z/) && name.bytesize <= 57
            raise ArgumentError, "Invalid storage name: #{name}"
          end
          unless path.start_with?("/") && !path.include?(":") && path != "/"
            raise ArgumentError, "Storage requires an absolute container path"
          end
          if storage_requirements.any? { |storage| storage[:name] == name || storage[:path] == path }
            raise ArgumentError, "Duplicate storage name or path: #{name}"
          end
          storage_requirements << {name: name, path: path, size: size, fs_group: fs_group}
        end

        def compose_volumes
          return @compose_volumes if defined?(@compose_volumes)

          @compose_volumes = Mobilis::Compose::Volume.new
        end

        def compose_volumes_overrides
          return @compose_volumes_overrides if defined?(@compose_volumes_overrides)

          @compose_volumes_overrides = Mobilis::Compose::Volume.new(base: compose_volumes)
        end

        def add_volume(source, target, override: false)
          if override
            compose_volumes_overrides.add(source, target)
          else
            compose_volumes.add(source, target)
          end
        end
      end
    end
  end
end
