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
  for (const topologyId of Object.keys(selection)) {
    const node = renderedNodes.find(candidate => candidate.id.includes(topologyId));
    if (!node) continue;

    node.setAttribute("role", "button");
    node.setAttribute("tabindex", "0");
    node.setAttribute("aria-label", `Focus ${node.textContent.trim()}`);
    const select = () => document.dispatchEvent(new CustomEvent("mobilis:service-select", {
      detail: { topologyId }
    }));
    node.addEventListener("click", select);
    node.addEventListener("keydown", event => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      select();
    });
  }
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
