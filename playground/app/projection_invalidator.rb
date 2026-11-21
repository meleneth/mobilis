# frozen_string_literal: true

module MobilisPlayground
  # An explicit, event-driven invalidation graph. No polling or observables.
  class ProjectionInvalidator
    REGIONS = {
      "editor-region" => [:render_editor, %i[source]],
      "builder-region" => [:render_builder, %i[system]],
      "inspector-region" => [:render_inspector, %i[system]],
      "architecture-region" => [:render_architecture, %i[system validation]],
      "diagnostics-region" => [:render_diagnostics, %i[validation generation]],
      "files-region" => [:render_files, %i[generated_files selected_file]],
      "file-content-region" => [:render_file_content, %i[generated_files selected_file]]
    }.freeze
    INPUTS = REGIONS.values.flat_map(&:last).uniq.freeze

    def affected(*changes)
      unknown = changes.uniq - INPUTS
      raise ArgumentError, "Unknown projection inputs: #{'#{unknown.inspect}'}" unless unknown.empty?

      REGIONS.filter_map do |region, (renderer, dependencies)|
        [region, renderer] unless (dependencies & changes).empty?
      end
    end
  end
end
