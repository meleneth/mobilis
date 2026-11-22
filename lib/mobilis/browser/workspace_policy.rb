# frozen_string_literal: true

module Mobilis
  module Browser
    # A shared policy configures both the browser editor and the static manifest.
    # Diesl owns the builder and the persisted workspace schema.
    module WorkspacePolicy
      def self.configure(builder, codec:)
        builder.root "/workspace"
        builder.source "mobilis.rb", last_valid: ".mobilis/last-valid.rb"
        builder.storage :browser
        builder.generated "generate"
        builder.git branch: "main", author_name: "Mobilis Playground",
          author_email: "playground@mobilis.local", stage: [:generated]
        builder.embedded :embedded_archive, codec:
        nil
      end

      def self.manifest(codec:)
        builder = Diesl::Workspace::Builder.new
        configure(builder, codec:)
        builder.build.manifest
      end
    end
  end
end
