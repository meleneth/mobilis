import * as Turbo from "/vendor/turbo.es2017-esm.js";
import mermaid from "/vendor/mermaid/mermaid.esm.min.mjs";
import { BlobReader, BlobWriter, ZipWriter } from "/vendor/zip/index.js";
import { RubyVM } from "/vendor/ruby-wasm-wasi/vm.js";
import { consolePrinter } from "/vendor/ruby-wasm-wasi/console.js";
import { Directory, File, OpenFile, PreopenDirectory, WASI } from "/vendor/wasi/index.js";

window.Turbo = Turbo;
mermaid.initialize({
  startOnLoad: false,
  securityLevel: "strict",
  theme: "base",
  flowchart: { htmlLabels: false, useMaxWidth: true, curve: "basis" },
  themeVariables: {
    background: "#111a22",
    primaryTextColor: "#e4edf4",
    lineColor: "#64748b",
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"
  }
});

window.MobilisDiagram = createDiagramRenderer();
window.MobilisSelection = createSelectionController();
installEventGate();
window.MobilisDownloads = {
  file(name, base64) {
    const bytes = Uint8Array.from(atob(base64), character => character.charCodeAt(0));
    download(name, new Blob([bytes], { type: "application/octet-stream" }));
  },
  async project(entries, filename = "mobilis-project.zip") {
    const writer = new ZipWriter(new BlobWriter("application/zip"));
    for (const [name, base64] of Object.entries(entries)) {
      const bytes = Uint8Array.from(atob(base64), character => character.charCodeAt(0));
      await writer.add(name, new BlobReader(new Blob([bytes])));
    }
    download(filename, await writer.close());
  }
};

function createDiagramRenderer() {
  let generation = 0;
  let lastSuccessful = null;

  return {
    async render(source, serializedSelection) {
      const currentGeneration = ++generation;
      const selection = JSON.parse(serializedSelection);

      try {
        const result = await mermaid.render(`mobilis-architecture-${currentGeneration}`, source);
        if (currentGeneration !== generation) return;

        const target = document.getElementById("architecture-canvas");
        if (!target) return;

        target.innerHTML = result.svg;
        result.bindFunctions?.(target);
        bindDiagramSelection(target, selection);
        lastSuccessful = { svg: result.svg, selection };
      } catch (error) {
        if (currentGeneration !== generation) return;

        const target = document.getElementById("architecture-canvas");
        if (!target) return;

        target.replaceChildren();
        if (lastSuccessful) {
          target.innerHTML = lastSuccessful.svg;
          bindDiagramSelection(target, lastSuccessful.selection);
        }
        const message = document.createElement("p");
        message.className = "diagram-render-error m-3 rounded border border-red-950 bg-red-950/40 p-3 text-xs text-red-300";
        message.textContent = `Architecture rendering failed: ${error.message || String(error)}`;
        target.append(message);
        console.error("Mermaid architecture rendering failed", error);
      }
    }
  };
}

function bindDiagramSelection(target, selection) {
  const renderedNodes = Array.from(target.querySelectorAll(".node"));
  for (const [topologyId, metadata] of Object.entries(selection.nodes)) {
    const node = renderedNodes.find(candidate => candidate.id.includes(topologyId));
    if (!node) continue;

    node.setAttribute("role", "button");
    node.setAttribute("tabindex", "0");
    node.setAttribute("aria-label", `Focus ${node.textContent.trim()}`);
    const select = () => window.MobilisSelection.select(topologyId, metadata);
    node.addEventListener("click", select);
    node.addEventListener("keydown", event => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      select();
    });
  }

  const renderedEdges = Array.from(target.querySelectorAll(".edgePath"));
  selection.edges.forEach((metadata, index) => {
    const edge = renderedEdges[index];
    if (!edge || metadata.startOffset == null) return;

    edge.setAttribute("role", "button");
    edge.setAttribute("tabindex", "0");
    edge.setAttribute("aria-label", "Focus relationship source");
    const select = () => {
      if (metadata.from) window.MobilisSelection.select(metadata.from, metadata, false);
      window.MobilisSelection.focusRange(metadata.startOffset, metadata.endOffset);
    };
    edge.addEventListener("click", select);
    edge.addEventListener("keydown", event => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      select();
    });
  });
  window.MobilisSelection.refresh();
}

function createSelectionController() {
  let selectedId = null;

  function focusRange(startOffset, endOffset) {
    if (startOffset == null || endOffset == null) return;
    const editor = document.getElementById("dsl-source");
    if (!editor) return;
    editor.focus({ preventScroll: true });
    editor.setSelectionRange(Number(startOffset), Number(endOffset));
  }

  function refresh() {
    const inspectors = Array.from(document.querySelectorAll(".service-inspector"));
    if (inspectors.length === 0) return;
    if (!inspectors.some(inspector => inspector.dataset.inspectorId === selectedId)) {
      selectedId = inspectors[0].dataset.inspectorId;
    }
    applySelection();
  }

  function applySelection() {
    document.querySelectorAll(".diagram-selected").forEach(element => element.classList.remove("diagram-selected"));
    document.querySelectorAll(".diagram-node-selected").forEach(element => element.classList.remove("diagram-node-selected"));
    document.querySelectorAll(".service-inspector").forEach(inspector => {
      inspector.classList.toggle("hidden", inspector.dataset.inspectorId !== selectedId);
    });

    const card = document.querySelector(`.service-card[data-topology-id="${CSS.escape(selectedId || "")}"]`);
    card?.classList.add("diagram-selected");
    const diagramNode = Array.from(document.querySelectorAll("#architecture-canvas .node"))
      .find(node => node.id.includes(selectedId || "__missing__"));
    diagramNode?.classList.add("diagram-node-selected");
  }

  return {
    refresh,
    focusRange,
    select(topologyId, metadata = {}, navigate = true) {
      selectedId = topologyId;
      applySelection();
      const card = document.querySelector(`.service-card[data-topology-id="${CSS.escape(topologyId)}"]`);
      card?.scrollIntoView({ block: "nearest", behavior: "smooth" });
      if (navigate) {
        const start = metadata.startOffset ?? card?.dataset.sourceStart;
        const end = metadata.endOffset ?? card?.dataset.sourceEnd;
        focusRange(start, end);
      }
    },
    selectedId() { return selectedId; }
  };
}

function installEventGate() {
  document.addEventListener("input", event => {
    if (event.target.id !== "dsl-source") return;
    document.dispatchEvent(new CustomEvent("mobilis:source-input", { detail: { target: event.target } }));
  });

  document.addEventListener("change", event => {
    if (!event.target.matches(".service-name, .service-type, .service-property, .inspector-service-property, .relationship-kind, .relationship-target, .relationship-property")) return;
    document.dispatchEvent(new CustomEvent("mobilis:semantic-change", { detail: { target: event.target } }));
  });

  document.addEventListener("click", event => {
    const target = event.target.closest("button");
    if (!target) return;

    if (target.matches(".select-service")) {
      event.preventDefault();
      const card = target.closest(".service-card");
      window.MobilisSelection.select(target.dataset.topologyId, {
        startOffset: card?.dataset.sourceStart,
        endOffset: card?.dataset.sourceEnd
      });
      return;
    }
    if (target.matches(".focus-source")) {
      event.preventDefault();
      window.MobilisSelection.focusRange(target.dataset.startOffset, target.dataset.endOffset);
      return;
    }

    const semanticClass = target.matches(".remove-service, .remove-relationship, .add-relationship, .file-link");
    const semanticId = [
      "add-service", "add-dependency", "generate-button", "download-dsl",
      "download-authoring-bundle", "download-file", "download-project"
    ].includes(target.id);
    if (!semanticClass && !semanticId) return;

    event.preventDefault();
    document.dispatchEvent(new CustomEvent("mobilis:semantic-click", { detail: { target } }));
  });
}

function download(name, blob) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}

async function boot() {
  try {
    const [wasmResponse, filesystemResponse] = await Promise.all([
      fetch("/mobilis.wasm"),
      fetch("/filesystem.json")
    ]);
    const [module, filesystem] = await Promise.all([
      WebAssembly.compileStreaming(wasmResponse),
      filesystemResponse.json()
    ]);
    const root = hydrateFilesystem(filesystem);
    const fds = [
      new OpenFile(new File([])),
      new OpenFile(new File([])),
      new OpenFile(new File([])),
      new PreopenDirectory("/", root.contents)
    ];
    const wasi = new WASI([], [], fds, { debug: false });
    const printer = consolePrinter();
    const { vm } = await RubyVM.instantiateModule({
      module,
      wasip1: wasi,
      addToImports: imports => printer.addToImports(imports),
      setMemory: memory => printer.setMemory(memory)
    });
    vm.eval(`$LOAD_PATH.unshift("/gems/haml", "/gems/temple", "/gems/thor", "/gems/tilt", "/src/lib", "/src/playground/app"); require "boot"`);
  } catch (error) {
    const target = document.querySelector("#boot") || document.querySelector("#app");
    target.innerHTML = `<div class="max-w-xl p-6 text-red-300"><strong>Runtime failed to initialize.</strong><pre class="mt-3 whitespace-pre-wrap">${escapeHtml(error.stack || String(error))}</pre></div>`;
    console.error(error);
    throw error;
  }
}

function hydrateFilesystem(files) {
  const root = new Directory(new Map());
  root.contents.set("tmp", new Directory(new Map()));
  root.contents.get("tmp").parent = root;

  for (const [path, base64] of Object.entries(files)) {
    const parts = path.split("/");
    const filename = parts.pop();
    let directory = root;
    for (const part of parts) {
      if (!directory.contents.has(part)) {
        const child = new Directory(new Map());
        child.parent = directory;
        directory.contents.set(part, child);
      }
      directory = directory.contents.get(part);
    }
    const bytes = Uint8Array.from(atob(base64), character => character.charCodeAt(0));
    directory.contents.set(filename, new File(bytes));
  }

  return root;
}

function escapeHtml(value) {
  const node = document.createElement("div");
  node.textContent = value;
  return node.innerHTML;
}

boot();
