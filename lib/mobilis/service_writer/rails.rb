module Mobilis
  module ServiceWriter
    class Rails < Mobilis::Base::ServiceWriter
      def write
        Dir.chdir("..")
        rails_builder.container_run("rails new #{@realized_node.name} .")
      end

      def rails_builder
        @manifest.plugin_for Mobilis::Plugin::RailsBuilder
      end
    end
  end
end
