# frozen_string_literal: true

require "json"

module MobilisPlayground
  class Application
    INITIAL_SOURCE = <<~RUBY
      # Everything in this editor stays in your browser.
      require "mobilis"

      Mobilis::DSL.generate("browser-demo", starting_port: 11_000) do
        postgres("database")
        redis("cache")

        connect(from: "cache", to: "database")
      end
    RUBY

    def initialize(renderer: Renderer.new)
      @renderer = renderer
      @runtime = Mobilis::Browser::SemanticRuntime.new
      @history = Mobilis::Browser::SourceHistory.new
      @source = INITIAL_SOURCE
      @analysis = @runtime.measure("initialize") { source_document.analyze }
      @topology = Mobilis::Browser::Topology.from_analysis(@analysis)
      @diagram_stale = false
      @errors = @analysis.errors
      @files = {}
      @selected_file = nil
      @status = "Runtime initialized. Source is valid and has not been transmitted."
      @generation = 0
      @event_handlers = []
    end

    def start
      document = JS.global[:document]
      document.call(:querySelector, "#boot").remove
      document.call(:querySelector, "#app")[:innerHTML] = @renderer.render(
        :layout,
        builder: render_builder,
        editor: render_editor,
        inspector: render_inspector,
        runtime_metrics: render_runtime_metrics,
        architecture: render_architecture,
        files: render_files,
        file_content: render_file_content,
        diagnostics: render_diagnostics
      )
      bind_events(document)
      render_diagram
      refresh_selection
      self
    end

    private

    def bind_events(document)
      input_handler = proc { |event| semantic_request("validate source") { handle_input(event) } }
      click_handler = proc { |event| semantic_request("semantic action") { handle_click(event) } }
      change_handler = proc { |event| semantic_request("structured edit") { handle_change(event) } }
      archive_handler = proc { |event| semantic_request("embedded document commit") { handle_archive_commit(event) } }
      document.addEventListener("mobilis:source-input", &input_handler)
      document.addEventListener("mobilis:semantic-click", &click_handler)
      document.addEventListener("mobilis:semantic-change", &change_handler)
      document.addEventListener("mobilis:archive-commit", &archive_handler)
      @event_handlers.concat([input_handler, click_handler, change_handler, archive_handler])
    end

    def handle_input(event)
      target = event[:detail][:target]

      @source = target[:value].to_s
      analysis = source_document.analyze
      if analysis.valid?
        @analysis = analysis
        @topology = Mobilis::Browser::Topology.from_analysis(analysis)
        @diagram_stale = false
        @history.reset
        @errors = []
        @status = "Source is valid. Visual model updated locally."
        replace("builder-region", render_builder)
        replace("inspector-region", render_inspector)
      else
        @diagram_stale = true
        @errors = analysis.errors
        @status = "Source is invalid. The last valid visual model is preserved."
      end
      replace("architecture-region", render_architecture)
      render_diagram
      refresh_selection
      replace("diagnostics-region", render_diagnostics)
    end

    def handle_change(event)
      target = event[:detail][:target]
      classes = target[:classList]
      visual_control = %w[service-name service-type service-property inspector-service-property relationship-kind relationship-target relationship-property]
        .any? { |name| class_member?(classes, name) }
      return unless visual_control

      if %w[relationship-kind relationship-target relationship-property].any? { |name| class_member?(classes, name) }
        editor = target.call(:closest, ".relationship-editor")
        relationship_id = editor[:dataset][:relationshipId].to_s
        property = if class_member?(classes, "relationship-kind")
                     :kind
                   elsif class_member?(classes, "relationship-target")
                     :to
                   else
                     target[:dataset][:property].to_s
                   end
        value = target[:type].to_s == "checkbox" ? target[:checked].to_s == "true" : target[:value].to_s
        visual_edit { source_document.update_relationship(relationship_id, property, value) }
        return
      end

      container = target.call(:closest, ".service-card") || target.call(:closest, ".service-inspector")

      id = (container[:dataset][:serviceId] || container[:dataset][:sourceId]).to_s
      if class_member?(classes, "service-name")
        visual_edit { source_document.rename(id, target[:value].to_s) }
      elsif class_member?(classes, "service-type")
        visual_edit { source_document.change_type(id, target[:value].to_s) }
      elsif class_member?(classes, "service-property") || class_member?(classes, "inspector-service-property")
        property = target[:dataset][:property].to_s
        value = target[:type].to_s == "checkbox" ? target[:checked].to_s == "true" : target[:value].to_s
        visual_edit { source_document.update_property(id, property, value) }
      end
    end

    def handle_click(event)
      target = event[:detail][:target]

      id = target[:id].to_s
      if class_member?(target[:classList], "remove-service")
        card = target.call(:closest, ".service-card")
        visual_edit { source_document.remove(card[:dataset][:serviceId].to_s) }
      elsif class_member?(target[:classList], "remove-relationship")
        editor = target.call(:closest, ".relationship-editor")
        visual_edit { source_document.remove_relationship(editor[:dataset][:relationshipId].to_s) }
      elsif class_member?(target[:classList], "add-relationship")
        editor = target.call(:closest, ".new-relationship")
        from = editor[:dataset][:from].to_s
        to = editor.call(:querySelector, ".new-relationship-target")[:value].to_s
        kind = editor.call(:querySelector, ".new-relationship-kind")[:value].to_s
        visual_edit { source_document.add_relationship(from:, to:, kind:) }
      elsif class_member?(target[:classList], "file-link")
        @selected_file = target[:dataset][:path].to_s
        replace("files-region", render_files)
        replace("file-content-region", render_file_content)
      else
        handle_button(id)
      end
    rescue ArgumentError, KeyError, RuntimeError, TypeError => error
      report_error(error)
    end

    def handle_button(id)
      case id
      when "add-service"
        type = element("new-service-type")[:value].to_s
        name = element("new-service-name")[:value].to_s
        visual_edit { source_document.add(type, name) }
      when "add-connection"
        from = element("dependency-from")[:value].to_s
        to = element("dependency-to")[:value].to_s
        raise ArgumentError, "A service cannot depend on itself" if from == to

        visual_edit { source_document.add_relationship(from:, to:) }
      when "generate-button" then generate
      when "download-dsl" then download_dsl
      when "download-authoring-bundle" then download_authoring_bundle
      when "download-file" then download_file
      when "download-project" then download_project
      when "undo-source" then restore_history(:undo)
      when "redo-source" then restore_history(:redo)
      end
    end

    def visual_edit(label: "structured edit")
      changed = yield
      analysis = self.class.source_document(changed).analyze
      raise ArgumentError, analysis.errors.join("\n") unless analysis.valid?

      @history.record(@source, changed, label:)
      @source = changed
      @analysis = analysis
      @topology = Mobilis::Browser::Topology.from_analysis(analysis)
      @diagram_stale = false
      @errors = []
      @status = "Visual edit applied surgically to Ruby source."
      replace("editor-region", render_editor)
      replace("builder-region", render_builder)
      replace("inspector-region", render_inspector)
      replace("architecture-region", render_architecture)
      render_diagram
      refresh_selection
      replace("diagnostics-region", render_diagnostics)
    end

    def handle_archive_commit(event)
      detail = event[:detail]
      changed = source_document.commit_embedded_archive(
        detail[:archiveId].to_s,
        detail[:path].to_s,
        detail[:content].to_s,
        parent_revision: detail[:parentRevision].to_s
      )
      visual_edit(label: "embedded document edit") { changed }
      JS.global[:MobilisDocuments].call(:committed)
    rescue ArgumentError, KeyError, RuntimeError, TypeError => error
      report_error(error)
      JS.global[:MobilisDocuments].call(:commitFailed, error.message)
    end

    def restore_history(direction)
      changed = @history.public_send(direction, @source)
      analysis = self.class.source_document(changed).analyze
      raise ArgumentError, analysis.errors.join("\n") unless analysis.valid?

      @source = changed
      @analysis = analysis
      @topology = Mobilis::Browser::Topology.from_analysis(analysis)
      @diagram_stale = false
      @errors = []
      @status = "Structured source edit #{direction == :undo ? "undone" : "redone"}."
      replace("editor-region", render_editor)
      replace("builder-region", render_builder)
      replace("inspector-region", render_inspector)
      replace("architecture-region", render_architecture)
      render_diagram
      refresh_selection
      replace("diagnostics-region", render_diagnostics)
    end

    def generate
      current = source_document.analyze
      raise ArgumentError, "Fix the current Ruby source before generating" unless current.valid?

      generation = @generation += 1
      @status = "Generating with Mobilis…"
      @errors = []
      replace("diagnostics-region", render_diagnostics)

      result = Mobilis::Browser::Generator.new.call(current.system)
      return unless generation == @generation

      @files = result.files
      @selected_file = @files.keys.first
      @status = "Generated #{@files.length} files locally with Mobilis."
      replace("files-region", render_files)
      replace("file-content-region", render_file_content)
      replace("diagnostics-region", render_diagnostics)
    end

    def download_file
      content = @files.fetch(@selected_file)
      JS.global[:MobilisDownloads].call(:file, File.basename(@selected_file), encode64(content))
    end

    def download_project
      encoded = @files.transform_values { |content| encode64(content) }
      JS.eval("return window.MobilisDownloads.project(#{JSON.generate(encoded)})")
    end

    def download_dsl
      JS.global[:MobilisDownloads].call(:file, "mobilis.rb", encode64(@source))
    end

    def download_authoring_bundle
      current = source_document.analyze
      raise ArgumentError, "Fix the current Ruby source before exporting" unless current.valid?

      entries = Mobilis::Browser::AuthoringBundle.new(@source, current.system).files
        .transform_values { |content| encode64(content) }
      JS.eval("return window.MobilisDownloads.project(#{JSON.generate(entries)}, 'mobilis-authoring-bundle.zip')")
    end

    def encode64(content)
      [content].pack("m0")
    end

    def report_error(error)
      @errors = ["#{error.class}: #{error.message}"]
      @status = "The requested action failed."
      replace("diagnostics-region", render_diagnostics)
    end

    def replace(target, html)
      @renderer.apply(action: "update", target:, html:)
    end

    def element(id)
      JS.global[:document].call(:getElementById, id)
    end

    def class_member?(class_list, name)
      class_list.contains(name).to_s == "true"
    end

    def source_document
      self.class.source_document(@source)
    end

    def self.source_document(source)
      Mobilis::Browser::SourceDocument.new(source)
    end

    def render_builder
      capabilities = Mobilis::Browser::Capabilities.for_system(@analysis.system)
      inspector_services = service_inspector.services
      @renderer.render(
        :builder,
        declarations: @analysis.declarations,
        service_types: Mobilis::Browser::SourceDocument::SERVICE_TYPES,
        property_schemas: Mobilis::Browser::SourceDocument::PROPERTY_SCHEMAS,
        inspector_services:,
        capabilities:
      )
    end

    def render_editor
      @renderer.render(:editor, source: @source, history: @history)
    end

    def render_architecture
      @renderer.render(:architecture, topology: @topology, stale: @diagram_stale)
    end

    def render_inspector
      @renderer.render(
        :inspector,
        services: service_inspector.services,
        documents: Mobilis::Browser::VirtualDocument.new(@analysis),
        archives: @analysis.archives
      )
    end

    def service_inspector
      Mobilis::Browser::ServiceInspector.new(@analysis, @topology)
    end

    def render_diagram
      return if @topology.empty?

      nodes = @topology.nodes.to_h do |node|
        [node.id, {sourceId: node.source_id, startOffset: node.start_offset, endOffset: node.end_offset}]
      end
      edges = @topology.edges.map do |edge|
        {sourceId: edge.source_id, startOffset: edge.start_offset, endOffset: edge.end_offset, from: edge.from}
      end
      diagram = Mobilis::Browser::MermaidDiagram.new(@topology).source
      JS.global[:MobilisDiagram].call(:render, diagram, JSON.generate(nodes: nodes, edges: edges))
    end

    def refresh_selection
      JS.global[:MobilisSelection].call(:refresh)
      JS.global[:MobilisDocuments].call(:refresh)
    end

    def render_files
      @renderer.render(:files, files: @files, selected_file: @selected_file)
    end

    def render_file_content
      @renderer.render(
        :file_content,
        selected_file: @selected_file,
        file_content: @selected_file ? @files.fetch(@selected_file) : nil
      )
    end

    def render_diagnostics
      @renderer.render(:diagnostics, errors: @errors, status: @status)
    end

    def render_runtime_metrics
      @renderer.render(:runtime_metrics, runtime: @runtime)
    end

    def semantic_request(label)
      @runtime.measure(label) { yield }
    ensure
      replace("runtime-metrics-region", render_runtime_metrics) if element("runtime-metrics-region")
    end
  end
end
