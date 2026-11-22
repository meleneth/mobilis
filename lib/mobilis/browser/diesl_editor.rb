# frozen_string_literal: true

require "diesl"
require "mobilis"

module Mobilis
  module Browser
    # Narrow translation layer. SourceDocument remains the only authority on
    # Mobilis AST edits, service semantics and embedded archives. Diesl owns
    # revisions, mutation validation and undo/redo.
    class DieslSourceDocument
      def initialize(source)
        @document = SourceDocument.new(source)
      end

      def analyze = @document.analyze

      def add_service(type:, name:) = @document.add(type, name)
      def rename_service(id:, name:) = @document.rename(id, name)
      def rename_service_with_references(id:, name:) = @document.rename_with_references(id, name)
      def update_starting_port(value:) = @document.update_starting_port(value)
      def change_service_type(id:, type:) = @document.change_type(id, type)
      def remove_service(id:) = @document.remove(id)
      def update_service_property(id:, property:, value:) = @document.update_property(id, property, value)

      def add_relationship(from:, to:, kind: :connect, properties: {})
        @document.add_relationship(from:, to:, kind:, properties:)
      end

      def update_relationship(id:, property:, value:)
        @document.update_relationship(id, property, value)
      end

      def remove_relationship(id:) = @document.remove_relationship(id)

      def commit_embedded_document(id:, path:, content:, parent_revision:)
        @document.commit_embedded_archive(id, path, content, parent_revision:)
      end
    end

    DIESL_SOURCE_ADAPTER = Diesl::SourceAdapter.new(
      document_class: DieslSourceDocument,
      operations: {
        add_service: :add_service,
        rename_service: :rename_service,
        rename_service_with_references: :rename_service_with_references,
        update_starting_port: :update_starting_port,
        change_service_type: :change_service_type,
        remove_service: :remove_service,
        update_service_property: :update_service_property,
        add_relationship: :add_relationship,
        update_relationship: :update_relationship,
        remove_relationship: :remove_relationship,
        commit_embedded_document: :commit_embedded_document
      }
    )

    # Only the authoring/record schema lives here. Domain interpretation and
    # source transforms stay in SourceDocument; this never executes generators.
    DIESL_EDITOR = Diesl::Editor.define do
      workspace do
        root "/workspace"
        source "mobilis.rb", last_valid: ".mobilis/last-valid.rb"
        storage :browser
        generated "generate"
        git branch: "main", author_name: "Mobilis Playground",
          author_email: "playground@mobilis.local", stage: [:generated]
        embedded :embedded_archive, codec: Mobilis::EmbeddedArchive
      end

      source_adapter Mobilis::Browser::DIESL_SOURCE_ADAPTER

      Mobilis::Browser::SourceDocument::SERVICE_TYPES.each do |kind|
        entity kind, label: kind.to_s.tr("_", " ").capitalize, creatable: true do
          field :name, type: :string, required: true
          Mobilis::Browser::SourceDocument::PROPERTY_SCHEMAS.fetch(kind, {}).each do |property, specification|
            # Keep the schema complete, including collection-valued fields.
            # Rendering is a separate concern, but the editor definition must
            # describe every supported source transformation.
            field property, type: specification.fetch(:kind), default: specification.fetch(:default)
          end
        end
      end
    end
  end
end
