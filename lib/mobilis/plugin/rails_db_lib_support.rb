# frozen_string_literal: true

module Mobilis
  module Plugin
    # This plugin exists make sure Rails dockerfiles install needed db libraries and headers
    class RailsDBLibSupport < Mobilis::Base::Plugin
      extend Forwardable

      def hook_after_services_written
        @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
          next unless realized_node.primary_database

          build_packages = realized_node.primary_database.build_packages
          runtime_packages = realized_node.primary_database.runtime_packages

          directory_service.chdir_project(realized_node)
          Mobilis::FileLines.edit("Dockerfile") do
            install_line = "apt-get install --no-install-recommends -y #{runtime_packages.join("")}"
            should_install = true
            lines.each do |line|
              should_install = false if line.include? install_line
            end
            if should_install
              gsub_lines(/pkg-config/, "pkg-config #{build_packages.join(" ")}")
              insert_before(/Run and own/,
                            "RUN apt-get update -qq && \\",
                            "  #{install_line} && \\",
                            "  rm -rf /var/lib/apt/lists /var/cache/apt/archives")
            end
          end
        end
        commit_all "Augment Rails dockerfiles for db library packages"
      end

      #  def hook_after_dc_helpers
      #    @manifest.each_node_of_type(Mobilis::Realized::Rails) do |realized_env, realized_node|
      #      next unless realized_node.primary_database

      #      directory_service.chdir_generate
      #      gems_to_add = []
      #      gems_to_add.concat realized_node.primary_database.additional_gems
      #      gems_to_add.uniq!
      #      Mobilis::Util.run_command(["./dc_test", realized_node.name, "bundle", "add", *gems_to_add])
      #    end
      #  end

      def ppx_fields(dsl)
        dsl.child_object "manifest", manifest
      end
    end
  end
end
