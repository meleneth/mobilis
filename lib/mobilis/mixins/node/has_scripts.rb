# frozen_string_literal: true

module Mobilis
  module Mixins
    module Node
      # Mixin to add script support to Node
      module HasScripts
        def add_script(filename, contents)
          models << Mobilis::Model::Script.new(filename, contents)
        end

        def write_file(path, contents)
          models << Mobilis::Model::File.new(path, contents)
        end

        def add_gem(name, git: nil, branch: nil, group: nil, require_name: nil)
          models << Mobilis::Model::RubyGem.new(
            name,
            git: git,
            branch: branch,
            group: group,
            require_name: require_name
          )
        end
      end
    end
  end
end
