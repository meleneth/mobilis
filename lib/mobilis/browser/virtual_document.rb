# frozen_string_literal: true

require "digest"

module Mobilis
  module Browser
    class VirtualDocument
      Document = Data.define(
        :id, :kind, :parent_id, :name, :path, :content_type, :revision,
        :dirty, :editable, :content_base64, :archive_id, :parent_revision
      )

      attr_reader :analysis

      def initialize(analysis)
        @analysis = analysis
      end

      def documents
        [source_document, *archive_documents].freeze
      end

      def archives
        documents.select { |document| document.kind == :archive }
      end

      def members(archive_id)
        documents.select { |document| document.kind == :member && document.archive_id == archive_id }
      end

      private

      def source_document
        Document.new(
          id: "ruby-source",
          kind: :source,
          parent_id: nil,
          name: "mobilis.rb",
          path: nil,
          content_type: "text/x-ruby",
          revision: Digest::SHA256.hexdigest(analysis.source),
          dirty: false,
          editable: true,
          content_base64: nil,
          archive_id: nil,
          parent_revision: nil
        )
      end

      def archive_documents
        analysis.archives.flat_map do |archive|
          archive_document = Document.new(
            id: archive.id,
            kind: :archive,
            parent_id: "ruby-source",
            name: archive.name,
            path: nil,
            content_type: "application/x-tar+base64",
            revision: Digest::SHA256.hexdigest(archive.payload.to_s),
            dirty: false,
            editable: false,
            content_base64: nil,
            archive_id: archive.id,
            parent_revision: archive.parent_revision
          )
          members = (archive.bundle&.entries || []).map do |entry|
            Document.new(
              id: member_id(archive.id, entry.path),
              kind: :member,
              parent_id: archive.id,
              name: File.basename(entry.path),
              path: entry.path,
              content_type: entry.content_type,
              revision: entry.sha256,
              dirty: false,
              editable: entry.content_type.start_with?("text/"),
              content_base64: [entry.content].pack("m0"),
              archive_id: archive.id,
              parent_revision: archive.parent_revision
            )
          end
          [archive_document, *members]
        end
      end

      def member_id(archive_id, path)
        "member-#{Digest::SHA256.hexdigest("#{archive_id}\0#{path}")[0, 20]}"
      end
    end
  end
end
