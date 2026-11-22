# frozen_string_literal: true

module Mobilis
  module Browser
    # One block describes the whole persisted browser workspace. The real
    # editor supplies the Mobilis archive codec; the static builder only needs
    # a codec-shaped placeholder to serialize the transport-safe manifest.
    module WorkspacePolicy
      def self.definition(codec:)
        proc do
          root "/workspace"
          source "mobilis.rb", last_valid: ".mobilis/last-valid.rb"
          storage :browser
          generated "generate"
          git branch: "main", author_name: "Mobilis Playground",
            author_email: "playground@mobilis.local", stage: [:generated]
          embedded :embedded_archive, codec:
        end
      end

      def self.manifest(codec:)
        builder = Diesl::Workspace::Builder.new
        builder.instance_eval(&definition(codec:))
        builder.build.manifest
      end
    end
  end
end
