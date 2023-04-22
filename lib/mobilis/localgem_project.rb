# frozen_string_literal: true

require "mobilis/generic_project"
require "mobilis/os"

module Mobilis
class LocalgemProject < GenericProject

def name
  @data[:name]
end

def generate
  Dir.mkdir "localgems"
  Dir.chdir name do
    run_command "bundle gem #{name}"
  end
end

end
end
