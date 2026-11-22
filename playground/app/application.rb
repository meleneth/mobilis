# frozen_string_literal: true

require "json"

module MobilisPlayground
  class Application
    REGION_RENDERERS = {
      :"editor-region" => :render_editor,
      :"builder-region" => :render_builder,
      :"inspector-region" => :render_inspector,
      :"architecture-region" => :render_architecture,
      :"diagnostics-region" => :render_diagnostics,
      :"files-region" => :render_files,
      :"file-content-region" => :render_file_content
    }.freeze

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
      graph = Carbn::Graph.define do
        state :source, initial: 0
        state :system, initial: 0
        state :validation, initial: 0
        state :generation, initial: 0
        state :generated_files, initial: 0
        state :selected_file, initial: 0
        region :"editor-region", depends_on: [:source]
        region :"builder-region", depends_on: [:system]
        region :"inspector-region", depends_on: [:system]
        region :"architecture-region", depends_on: [:system, :validation]
        region :"diagnostics-region", depends_on: [:validation, :generation]
        region :"files-region", depends_on: [:generated_files, :selected_file]
        region :"file-content-region", depends_on: [:generated_files, :selected_file]
      end
      @reactivity = Carbn::Store.new(graph)
      @reactivity.subscribe do |regions, _revision|
        regions.each { |region| replace(region.to_s, __send__(REGION_RENDERERS.fetch(region))) }
      end
      @runtime = Mobilis::Browser::SemanticRuntime.new
      @generator_compatibility = Mobilis::Browser::GeneratorCompatibility.new
      @sync_service_renames = true
      bootstrap_source = workspace_property(:bootstrapSource)
      bootstrap_valid_source = workspace_property(:bootstrapValidSource)
      @source = bootstrap_source.empty? ? INITIAL_SOURCE : bootstrap_source
      current = @runtime.measure("initialize") { source_document.analyze }
      fallback = bootstrap_valid_source.empty? ? INITIAL_SOURCE : bootstrap_valid_source
      @session = Mobilis::Browser::DIESL_EDITOR.adapted_session(source: current.valid? ? @source : fallback)
      @session.type_source(@source, expected_revision: @session.revision) unless current.valid?
      @analysis = @session.analysis
      @topology = Mobilis::Browser::Topology.from_analysis(@analysis)
      @diagram_stale = !current.valid?
      @errors = current.errors
      @files = {}
      @selected_file = nil
      @status = if current.valid?
                  "Runtime initialized. Source is valid and persisted locally."
                else
                  "Persisted source is invalid. The last valid visual model is preserved."
                end
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
        workspace: render_workspace,
        files: render_files,
        file_content: render_file_content,
        diagnostics: render_diagnostics
      )
      bind_events(document)
      persist_source(valid: current_source_valid?)
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
      checkout_handler = proc { |event| semantic_request("workspace checkout") { handle_workspace_checkout(event) } }
      rename_sync_handler = proc { |event| @sync_service_renames = event[:detail][:enabled].to_s == "true" }
      source_blur_handler = proc do |event|
        @session.end_source_edit if event[:target][:id].to_s == "dsl-source"
        nil
      end
      generated_handler = proc do |event|
        commits = event[:detail][:commits].to_i
        files = event[:detail][:files].to_i
        @status = "Generated #{files} files with #{commits} committed Mobilis phases. ZIP ready."
        @errors = []
        update_regions(:generation)
        nil # DOM event callbacks must not return Ruby arrays into the JS bridge.
      end
      generation_failure_handler = proc do |event|
        @status = "Project generation failed while writing Git history."
        @errors = [event[:detail][:error].to_s]
        update_regions(:validation)
        nil
      end
      compatibility_handler = proc do |event|
        semantic_request("generator compatibility shim") { handle_generator_compatibility(event) }
      end
      document.addEventListener("mobilis:source-input", &input_handler)
      document.addEventListener("focusout", &source_blur_handler)
      document.addEventListener("mobilis:generation-complete", &generated_handler)
      document.addEventListener("mobilis:generation-failed", &generation_failure_handler)
      document.addEventListener("mobilis:rename-sync-toggle", &rename_sync_handler)
      document.addEventListener("mobilis:semantic-click", &click_handler)
      document.addEventListener("mobilis:semantic-change", &change_handler)
      document.addEventListener("mobilis:archive-commit", &archive_handler)
      document.addEventListener("mobilis:workspace-checkout", &checkout_handler)
      document.addEventListener("mobilis:generator-compatibility", &compatibility_handler)
      @event_handlers.concat(
        [input_handler, source_blur_handler, generated_handler, generation_failure_handler, rename_sync_handler, click_handler, change_handler, archive_handler, checkout_handler, compatibility_handler]
      )
    end

    def handle_generator_compatibility(event)
      detail = event[:detail]
      request = JSON.parse(detail[:request].to_s, symbolize_names: true)
      plan = @generator_compatibility.plan(
        generator: request.fetch(:generator),
        version: request.fetch(:version),
        arguments: request.fetch(:arguments),
        encoded_files: request.fetch(:files)
      )
      detail[:response] = JSON.generate(plan)
      detail[:accepted] = true
    rescue ArgumentError, KeyError, JSON::ParserError, TypeError,
           Mobilis::GeneratorCompatibility::UnsupportedInvocationError,
           Mobilis::GeneratorCompatibility::WorkspaceConflictError => error
      detail[:accepted] = false if detail
      detail[:error] = "#{error.class}: #{error.message}" if detail
    end

    def handle_input(event)
      target = event[:detail][:target]

      edited = target[:value].to_s
      if event[:detail][:replaceAll].to_s != "true" && @sync_service_renames && !@diagram_stale
        synchronized = source_document.propagate_service_rename(edited)
        if synchronized && synchronized != edited
          selection_start = target[:selectionStart].to_i
          selection_end = target[:selectionEnd].to_i
          target[:value] = synchronized
          target.call(:setSelectionRange, selection_start, selection_end)
          edited = synchronized
        end
      end

      @session.type_source(edited, expected_revision: @session.revision)
      @source = @session.draft_source
      if @session.draft_valid?
        analysis = @session.analysis
        @analysis = analysis
        @topology = Mobilis::Browser::Topology.from_analysis(analysis)
        @diagram_stale = false
        @errors = []
        @status = "Source is valid. Visual model updated locally."
        persist_source(valid: true)
      else
        @diagram_stale = true
        @errors = [@session.draft_error]
        @status = "Source is invalid. The last valid visual model is preserved."
        persist_source(valid: false)
      end
      update_regions(*(event[:detail][:replaceAll].to_s == "true" ? [:source, :system, :validation] : [:system, :validation]))
      render_diagram
      refresh_history_controls
      refresh_selection
    end

    def handle_workspace_checkout(event)
      detail = event[:detail]
      changed = detail[:source].to_s
      analysis = self.class.source_document(changed).analyze
      raise ArgumentError, analysis.errors.join("\n") unless analysis.valid?

      @session = Mobilis::Browser::DIESL_EDITOR.adapted_session(source: changed)
      @source = @session.source
      @analysis = @session.analysis
      @topology = Mobilis::Browser::Topology.from_analysis(@analysis)
      @diagram_stale = false
      @errors = []
      @status = "Checked out Git revision and refreshed the validated project."
      update_regions(:source, :system, :validation)
      render_diagram
      refresh_selection
      detail[:accepted] = true
      detail[:valid] = true
    rescue ArgumentError, KeyError, RuntimeError, TypeError => error
      detail[:accepted] = false if detail
      detail[:error] = "#{error.class}: #{error.message}" if detail
    end

    def handle_change(event)
      target = event[:detail][:target]
      if target[:id].to_s == "system-starting-port"
        visual_edit(operation: :update_starting_port, value: target[:value].to_s)
        return
      end

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
        visual_edit(operation: :update_relationship, id: relationship_id, property:, value:)
        return
      end

      container = target.call(:closest, ".service-card") || target.call(:closest, ".service-inspector")

      id = if class_member?(container[:classList], "service-card")
             container[:dataset][:serviceId].to_s
           else
             container[:dataset][:sourceId].to_s
           end
      if class_member?(classes, "service-name")
        visual_edit(operation: (@sync_service_renames ? :rename_service_with_references : :rename_service), id:, name: target[:value].to_s)
      elsif class_member?(classes, "service-type")
        visual_edit(operation: :change_service_type, id:, type: target[:value].to_s)
      elsif class_member?(classes, "service-property") || class_member?(classes, "inspector-service-property")
        property = target[:dataset][:property].to_s
        value = target[:type].to_s == "checkbox" ? target[:checked].to_s == "true" : target[:value].to_s
        visual_edit(operation: :update_service_property, id:, property:, value:)
      end
    rescue ArgumentError, KeyError, RuntimeError, TypeError, Diesl::Conflict, Diesl::UnsafeEdit, Diesl::InvalidSource => error
      report_error(error)
    end

    def handle_click(event)
      target = event[:detail][:target]

      id = target[:id].to_s
      if class_member?(target[:classList], "remove-service")
        card = target.call(:closest, ".service-card")
        visual_edit(operation: :remove_service, id: card[:dataset][:serviceId].to_s)
      elsif class_member?(target[:classList], "remove-relationship")
        editor = target.call(:closest, ".relationship-editor")
        visual_edit(operation: :remove_relationship, id: editor[:dataset][:relationshipId].to_s)
      elsif class_member?(target[:classList], "add-relationship")
        editor = target.call(:closest, ".new-relationship")
        from = editor[:dataset][:from].to_s
        to = editor.call(:querySelector, ".new-relationship-target")[:value].to_s
        kind = editor.call(:querySelector, ".new-relationship-kind")[:value].to_s
        visual_edit(operation: :add_relationship, from:, to:, kind:)
      elsif class_member?(target[:classList], "file-link")
        @selected_file = target[:dataset][:path].to_s
        update_regions(:selected_file)
      else
        handle_button(id)
      end
    rescue ArgumentError, KeyError, RuntimeError, TypeError, LoadError, Diesl::Conflict, Diesl::UnsafeEdit, Diesl::InvalidSource => error
      report_error(error)
    end

    def handle_button(id)
      case id
      when "add-service"
        type = element("new-service-type")[:value].to_s
        name = element("new-service-name")[:value].to_s
        visual_edit(operation: :add_service, type:, name:)
      when "add-connection"
        from = element("dependency-from")[:value].to_s
        to = element("dependency-to")[:value].to_s
        raise ArgumentError, "A service cannot depend on itself" if from == to

        visual_edit(operation: :add_relationship, from:, to:)
      when "generate-button" then generate
      when "download-dsl" then download_dsl
      when "download-authoring-bundle" then download_authoring_bundle
      when "download-file" then download_file
      when "download-project" then download_project
      when "undo-source" then restore_history(:undo)
      when "redo-source" then restore_history(:redo)
      end
    end

    def visual_edit(operation:, **arguments)
      @session.apply(operation:, expected_revision: @session.revision, **arguments)
      refresh_valid_session("Visual edit applied surgically to Ruby source.")
    end

    def handle_archive_commit(event)
      detail = event[:detail]
      visual_edit(
        operation: :commit_embedded_document,
        id: detail[:archiveId].to_s,
        path: detail[:path].to_s,
        content: detail[:content].to_s,
        parent_revision: detail[:parentRevision].to_s
      )
      JS.global[:MobilisDocuments].call(:committed)
    rescue ArgumentError, KeyError, RuntimeError, TypeError, Diesl::Conflict, Diesl::UnsafeEdit, Diesl::InvalidSource => error
      report_error(error)
      JS.global[:MobilisDocuments].call(:commitFailed, error.message)
    end

    def restore_history(direction)
      @session.public_send(direction)
      refresh_valid_session("Ruby source edit #{direction == :undo ? "undone" : "redone"}.")
    end

    def refresh_valid_session(status)
      @source = @session.draft_source
      @analysis = @session.analysis
      @topology = Mobilis::Browser::Topology.from_analysis(@analysis)
      @diagram_stale = false
      @errors = []
      @status = status
      persist_source(valid: true)
      update_regions(:source, :system, :validation)
      render_diagram
      refresh_selection
    end

    def generate
      current = source_document.analyze
      raise ArgumentError, "Fix the current Ruby source before generating" unless current.valid?

      generation = @generation += 1
      @status = "Generating with Mobilis…"
      @errors = []
      update_regions(:generation)

      result = Mobilis::Browser::Generator.new.call(current.system)
      return unless generation == @generation

      @files = result.files
      @selected_file = @files.keys.first
      @status = "Generated #{@files.length} files; committing #{result.steps.length} Mobilis phases..."
      persist_generated_history(result.steps)
      update_regions(:generated_files, :generation)
    end

    def download_file
      content = @files.fetch(@selected_file)
      JS.global[:MobilisDownloads].call(:file, File.basename(@selected_file), encode64(content))
    end

    def download_project
      JS.global[:MobilisWorkspace].call(:downloadGeneratedProject)
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
      # Ruby WASM exceptions must retain their origin. A message alone hides
      # whether a generator failure came from Rails, Mobilis or filesystem I/O.
      trace = Array(error.backtrace).first(18)
      @errors = [["#{error.class}: #{error.message}", *trace].join("\n")]
      @status = "The requested action failed."
      update_regions(:validation)
    end

    def update_regions(*changes)
      @reactivity.transaction do
        changes.each { |name| @reactivity.set(name, @reactivity.get(name) + 1) }
      end
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
      html = @renderer.render(
        :builder,
        declarations: @analysis.declarations,
        service_types: Mobilis::Browser::DIESL_EDITOR.entities.keys,
        property_schemas: diesl_property_schemas,
        inspector_services:,
        capabilities:,
        starting_port: @analysis.system.starting_port,
        starting_port_editable: !@diagram_stale && source_document.starting_port_editable?
      )
      projection_warning + html
    end

    def render_editor
      @renderer.render(:editor, source: @source, history: @session.history, draft_valid: @session.draft_valid?, sync_service_renames: @sync_service_renames)
    end

    def render_architecture
      @renderer.render(:architecture, topology: @topology, stale: @diagram_stale)
    end

    def render_workspace
      @renderer.render(:workspace, compatibility_invocations: @generator_compatibility.manifests)
    end

    def render_inspector
      html = @renderer.render(
        :inspector,
        services: service_inspector.services,
        documents: Mobilis::Browser::VirtualDocument.new(@analysis),
        archives: @analysis.archives
      )
      projection_warning + html
    end

    def projection_warning
      return "" unless @diagram_stale

      @renderer.render(:projection_warning, errors: @errors)
    end

    def service_inspector
      Mobilis::Browser::ServiceInspector.new(@analysis, @topology, property_schemas: diesl_property_schemas)
    end

    # One declarative field schema feeds both visual editing surfaces.
    def diesl_property_schemas
      @diesl_property_schemas ||= Mobilis::Browser::DIESL_EDITOR.entities.transform_values do |schema|
        schema.fields.reject { |field| field.name == :name }.to_h do |field|
          [field.name, {kind: field.type, default: field.default}]
        end
      end
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

    # Never replace the active textarea on input just to refresh undo controls.
    # Diesl tracks typing transactions; update the two buttons in place.
    def refresh_history_controls
      history = @session.history
      {
        "undo-source" => ["Undo", history.undo_entries, !@session.draft_valid?],
        "redo-source" => ["Redo", history.redo_entries, false]
      }.each do |id, (verb, entries, invalid_draft)|
        button = element(id)
        next unless button

        entry = entries.last
        label = entry ? "#{verb} #{entry.label}" : (invalid_draft ? "Undo invalid Ruby draft" : verb)
        button[:disabled] = entries.empty? && !invalid_draft
        button[:textContent] = label
        button[:title] = label
      end
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
      # DOM events use their detail object for responses. Returning arbitrary
      # Ruby arrays here forces ruby.wasm to convert nested Ruby objects to JS,
      # masking the original generation error with a bridge TypeError.
      nil
    ensure
      replace("runtime-metrics-region", render_runtime_metrics) if element("runtime-metrics-region")
    end

    def persist_source(valid:)
      JS.global[:MobilisWorkspace].call(:persistSource, @source, valid)
    end

    def persist_generated_history(steps)
      records = steps.map do |step|
        {
          message: step.fetch(:message),
          writes: step.fetch(:writes).transform_values { |content| encode64(content) },
          deletes: step.fetch(:deletes)
        }
      end
      JS.global[:MobilisWorkspace].call(:persistGeneratedHistory, JSON.generate(records))
    end

    def persist_generated_files
      encoded = @files.transform_values { |content| encode64(content) }
      JS.global[:MobilisWorkspace].call(:persistGenerated, JSON.generate(encoded))
    end

    def workspace_property(name)
      value = JS.global[:MobilisWorkspace][name]
      value.nil? ? "" : value.to_s
    end

    def current_source_valid?
      @session.draft_valid?
    end
  end
end
