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
      @source = INITIAL_SOURCE
      @analysis = source_document.analyze
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
        architecture: render_architecture,
        files: render_files,
        file_content: render_file_content,
        diagnostics: render_diagnostics
      )
      bind_events(document)
      render_diagram
      self
    end

    private

    def bind_events(document)
      input_handler = proc { |event| handle_input(event) }
      click_handler = proc { |event| handle_click(event) }
      change_handler = proc { |event| handle_change(event) }
      diagram_handler = proc { |event| handle_diagram_selection(event) }
      document.addEventListener("input", &input_handler)
      document.addEventListener("click", &click_handler)
      document.addEventListener("change", &change_handler)
      document.addEventListener("mobilis:service-select", &diagram_handler)
      @event_handlers.concat([input_handler, click_handler, change_handler, diagram_handler])
    end

    def handle_input(event)
      target = event[:target]
      return unless target[:id].to_s == "dsl-source"

      @source = target[:value].to_s
      analysis = source_document.analyze
      if analysis.valid?
        @analysis = analysis
        @topology = Mobilis::Browser::Topology.from_analysis(analysis)
        @diagram_stale = false
        @errors = []
        @status = "Source is valid. Visual model updated locally."
        replace("builder-region", render_builder)
      else
        @diagram_stale = true
        @errors = analysis.errors
        @status = "Source is invalid. The last valid visual model is preserved."
      end
      replace("architecture-region", render_architecture)
      render_diagram
      replace("diagnostics-region", render_diagnostics)
    end

    def handle_change(event)
      target = event[:target]
      classes = target[:classList]
      visual_control = %w[service-name service-type service-property].any? { |name| class_member?(classes, name) }
      return unless visual_control

      card = target.call(:closest, ".service-card")

      id = card[:dataset][:serviceId].to_s
      if class_member?(classes, "service-name")
        visual_edit { source_document.rename(id, target[:value].to_s) }
      elsif class_member?(classes, "service-type")
        visual_edit { source_document.change_type(id, target[:value].to_s) }
      elsif class_member?(classes, "service-property")
        property = target[:dataset][:property].to_s
        value = target[:type].to_s == "checkbox" ? target[:checked].to_s == "true" : target[:value].to_s
        visual_edit { source_document.update_property(id, property, value) }
      end
    end

    def handle_click(event)
      target = event[:target]
      return unless target[:tagName].to_s == "BUTTON"

      event.call(:preventDefault)
      id = target[:id].to_s
      if class_member?(target[:classList], "remove-service")
        card = target.call(:closest, ".service-card")
        visual_edit { source_document.remove(card[:dataset][:serviceId].to_s) }
      elsif class_member?(target[:classList], "file-link")
        @selected_file = target[:dataset][:path].to_s
        replace("files-region", render_files)
        replace("file-content-region", render_file_content)
      else
        handle_button(id)
      end
    rescue StandardError => error
      report_error(error)
    end

    def handle_button(id)
      case id
      when "add-service"
        type = element("new-service-type")[:value].to_s
        name = element("new-service-name")[:value].to_s
        visual_edit { source_document.add(type, name) }
      when "add-dependency"
        from = element("dependency-from")[:value].to_s
        to = element("dependency-to")[:value].to_s
        raise ArgumentError, "A service cannot depend on itself" if from == to

        visual_edit { source_document.add_dependency(from:, to:) }
      when "generate-button" then generate
      when "download-dsl" then download_dsl
      when "download-authoring-bundle" then download_authoring_bundle
      when "download-file" then download_file
      when "download-project" then download_project
      end
    end

    def visual_edit
      changed = yield
      analysis = self.class.source_document(changed).analyze
      raise ArgumentError, analysis.errors.join("\n") unless analysis.valid?

      @source = changed
      @analysis = analysis
      @topology = Mobilis::Browser::Topology.from_analysis(analysis)
      @diagram_stale = false
      @errors = []
      @status = "Visual edit applied surgically to Ruby source."
      replace("editor-region", render_editor)
      replace("builder-region", render_builder)
      replace("architecture-region", render_architecture)
      render_diagram
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

    def handle_diagram_selection(event)
      topology_id = event[:detail][:topologyId].to_s
      node = @topology.node(topology_id)
      return unless node

      document = JS.global[:document]
      selected = document.call(:querySelectorAll, ".diagram-selected")
      selected[:length].to_i.times do |index|
        selected[index][:classList].remove("diagram-selected")
      end

      if node.source_id
        card = document.call(:querySelector, %(.service-card[data-service-id="#{node.source_id}"]))
        if card
          card[:classList].add("diagram-selected")
          card.call(:scrollIntoView, JS.eval("return {block: 'nearest', behavior: 'smooth'}"))
        end
      end

      return unless node.start_offset && node.end_offset

      editor = element("dsl-source")
      editor.call(:focus, JS.eval("return {preventScroll: true}"))
      editor.call(:setSelectionRange, node.start_offset, node.end_offset)
    end

    def source_document
      self.class.source_document(@source)
    end

    def self.source_document(source)
      Mobilis::Browser::SourceDocument.new(source)
    end

    def render_builder
      capabilities = Mobilis::Browser::Capabilities.for_system(@analysis.system)
      @renderer.render(
        :builder,
        declarations: @analysis.declarations,
        service_types: Mobilis::Browser::SourceDocument::SERVICE_TYPES,
        property_schemas: Mobilis::Browser::SourceDocument::PROPERTY_SCHEMAS,
        capabilities:
      )
    end

    def render_editor
      @renderer.render(:editor, source: @source)
    end

    def render_architecture
      @renderer.render(:architecture, topology: @topology, stale: @diagram_stale)
    end

    def render_diagram
      return if @topology.empty?

      selection = @topology.nodes.to_h do |node|
        [node.id, {sourceId: node.source_id, startOffset: node.start_offset, endOffset: node.end_offset}]
      end
      diagram = Mobilis::Browser::MermaidDiagram.new(@topology).source
      JS.global[:MobilisDiagram].call(:render, diagram, JSON.generate(selection))
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
  end
end
