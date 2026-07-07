# frozen_string_literal: true

module Mobilis
  module Mixins
    module Node
      # Mixin to add script support to Node
      module HasScripts
        def add_script(filename, contents)
          model = Mobilis::Model::Script.new(filename, contents)
          models << model
          model
        end

        def write_file(path, contents)
          model = Mobilis::Model::File.new(path, contents)
          models << model
          model
        end

        def add_gem(name, git: nil, branch: nil, group: nil, require_name: nil)
          model = Mobilis::Model::RubyGem.new(
            name,
            git: git,
            branch: branch,
            group: group,
            require_name: require_name
          )
          models << model
          model
        end
      end
    end
  end
end
