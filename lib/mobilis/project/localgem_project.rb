# frozen_string_literal: true

module Mobilis
  class LocalgemProject < GenericProject
    def name
      @data[:name]
    end

    def generate
      Dir.mkdir "localgems" unless Dir.exist? "localgems"
      Dir.chdir "localgems" do
        run_command "bundle gem #{name}", true
      end
    end
  end
end
