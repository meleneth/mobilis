import * as Turbo from "/vendor/turbo.es2017-esm.js";
import mermaid from "/vendor/mermaid/mermaid.esm.min.mjs";
import { BlobReader, BlobWriter, ZipWriter } from "/vendor/zip/index.js";
import { RubyVM } from "/vendor/ruby-wasm-wasi/vm.js";
import { consolePrinter } from "/vendor/ruby-wasm-wasi/console.js";
import { Directory, File, OpenFile, PreopenDirectory, WASI } from "/vendor/wasi/index.js";
import { createWorkspaceController } from "/workspace.js";

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
window.MobilisDocuments = createDocumentController();
window.MobilisWorkspace = createWorkspaceController();
window.MobilisRuntimeDiagnostics = {
  phase: "loading",
  vmInstances: 0,
  timings: {},
  runtime: null,
  application: null
};
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

function createDocumentController() {
  let active = null;

  function decodeText(base64) {
    const bytes = Uint8Array.from(atob(base64), character => character.charCodeAt(0));
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  }

  function render() {
    const workspace = document.getElementById("embedded-document-workspace");
    const rubyWorkspace = document.getElementById("ruby-document-workspace");
    if (!workspace) return;
    workspace.classList.toggle("hidden", !active);
    rubyWorkspace?.classList.toggle("hidden", Boolean(active));
    if (!active) return;

    const current = document.querySelector(`.open-embedded-member[data-document-id="${CSS.escape(active.documentId)}"]`);
    const conflicted = active.conflicted || !current || current.dataset.parentRevision !== active.parentRevision;
    const editor = document.getElementById("embedded-document-editor");
    editor.value = active.content;
    document.getElementById("embedded-document-path").textContent = active.path;
    document.getElementById("embedded-document-conflict").classList.toggle("hidden", !conflicted);
    updateDirtyState();
  }

  function updateDirtyState() {
    if (!active) return;
    const dirty = active.content !== active.original;
    const state = document.getElementById("embedded-document-state");
    const save = document.getElementById("save-embedded-document");
    if (state) state.textContent = dirty ? "Unsaved staged changes" : "Clean staged document";
    if (save) save.disabled = !dirty;
  }

  return {
    open(button) {
      const content = decodeText(button.dataset.contentBase64);
      active = {
        documentId: button.dataset.documentId,
        archiveId: button.dataset.archiveId,
        path: button.dataset.path,
        parentRevision: button.dataset.parentRevision,
        original: content,
        content
      };
      render();
      document.getElementById("embedded-document-editor")?.focus();
    },
    edit(content) {
      if (!active) return;
      active.content = content;
      updateDirtyState();
    },
    discard() {
      if (!active) return;
      active.content = active.original;
      render();
    },
    close() {
      active = null;
      render();
      document.getElementById("dsl-source")?.focus();
    },
    save() {
      if (!active || active.content === active.original) return;
      document.dispatchEvent(new CustomEvent("mobilis:archive-commit", { detail: {
        archiveId: active.archiveId,
        path: active.path,
        content: active.content,
        parentRevision: active.parentRevision
      } }));
    },
    committed() {
      active = null;
      render();
    },
    commitFailed(message) {
      const state = document.getElementById("embedded-document-state");
      if (state) state.textContent = `Save failed: ${message}`;
    },
    parentChanged() {
      if (!active) return;
      active.conflicted = true;
      render();
    },
    refresh: render,
    activeRevision() { return active?.parentRevision ?? null; },
    hasUnsavedChanges() { return Boolean(active && active.content !== active.original); }
  };
}

function installEventGate() {
  document.addEventListener("input", event => {
    if (event.target.id === "embedded-document-editor") {
      window.MobilisDocuments.edit(event.target.value);
      return;
    }
    if (event.target.id !== "dsl-source") return;
    window.MobilisDocuments.parentChanged();
    window.MobilisWorkspace.persistSource(event.target.value, false);
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
    if (target.matches(".open-embedded-member")) {
      event.preventDefault();
      window.MobilisDocuments.open(target);
      return;
    }
    if (target.id === "discard-embedded-document") {
      event.preventDefault();
      window.MobilisDocuments.discard();
      return;
    }
    if (target.id === "close-embedded-document") {
      event.preventDefault();
      window.MobilisDocuments.close();
      return;
    }
    if (target.id === "save-embedded-document") {
      event.preventDefault();
      window.MobilisDocuments.save();
      return;
    }

    const semanticClass = target.matches(".remove-service, .remove-relationship, .add-relationship, .file-link");
    const semanticId = [
      "add-service", "add-connection", "generate-button", "download-dsl",
      "download-authoring-bundle", "download-file", "download-project",
      "undo-source", "redo-source"
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
  const diagnostics = window.MobilisRuntimeDiagnostics;
  const totalStarted = performance.now();
  try {
    const workspacePromise = window.MobilisWorkspace.initialize();
    const configStarted = performance.now();
    const config = validateRuntimeConfig(await fetchJson("/runtime-config.json", "runtime configuration", { cache: "no-store" }));
    diagnostics.timings.configurationMs = elapsed(configStarted);
    diagnostics.runtime = config.runtime;

    const applicationPromise = loadApplication(config);
    const runtimeStarted = performance.now();
    const runtimeResponse = await fetchRequired(config.runtime.url, "pinned Ruby WASM runtime", {
      cache: "force-cache",
      integrity: config.runtime.integrity
    });
    const runtimeBytes = new Uint8Array(await runtimeResponse.arrayBuffer());
    await verifyBytes(runtimeBytes, config.runtime, "Ruby WASM runtime");
    diagnostics.timings.runtimeFetchAndVerifyMs = elapsed(runtimeStarted);

    const compileStarted = performance.now();
    const module = await WebAssembly.compile(runtimeBytes);
    diagnostics.timings.runtimeCompileMs = elapsed(compileStarted);

    const application = await applicationPromise;
    await workspacePromise;
    diagnostics.application = {
      version: application.manifest.application_version,
      files: application.files.size,
      bytes: application.archiveBytes
    };
    Object.assign(diagnostics.timings, application.timings);

    const hydrateStarted = performance.now();
    const root = hydrateFilesystem(application.files);
    diagnostics.timings.filesystemHydrationMs = elapsed(hydrateStarted);
    const fds = [
      new OpenFile(new File([])),
      new OpenFile(new File([])),
      new OpenFile(new File([])),
      new PreopenDirectory("/", root.contents)
    ];
    const wasi = new WASI([], [], fds, { debug: false });
    const printer = consolePrinter();
    const instantiateStarted = performance.now();
    const { vm } = await RubyVM.instantiateModule({
      module,
      wasip1: wasi,
      addToImports: imports => printer.addToImports(imports),
      setMemory: memory => printer.setMemory(memory)
    });
    diagnostics.vmInstances += 1;
    diagnostics.timings.vmInstantiationMs = elapsed(instantiateStarted);

    const rubyStarted = performance.now();
    const loadPaths = application.manifest.filesystem.load_paths.map(path => JSON.stringify(path)).join(", ");
    const bootFeature = JSON.stringify(application.manifest.filesystem.boot_feature);
    vm.eval(`$LOAD_PATH.unshift(${loadPaths}); require ${bootFeature}`);
    window.MobilisWorkspace.attach();
    diagnostics.timings.rubyApplicationLoadMs = elapsed(rubyStarted);
    diagnostics.timings.totalInitializationMs = elapsed(totalStarted);
    diagnostics.phase = "ready";
    const status = document.getElementById("runtime-status");
    if (status) status.title = `Ruby VM and Mobilis application initialized in ${diagnostics.timings.totalInitializationMs.toFixed(1)} ms`;
  } catch (error) {
    diagnostics.phase = "failed";
    diagnostics.timings.totalInitializationMs = elapsed(totalStarted);
    diagnostics.error = error.message || String(error);
    const target = document.querySelector("#boot") || document.querySelector("#app");
    target.innerHTML = `<div class="max-w-xl p-6 text-red-300"><strong>Runtime failed to initialize.</strong><pre class="mt-3 whitespace-pre-wrap">${escapeHtml(error.stack || String(error))}</pre></div>`;
    console.error(error);
    throw error;
  }
}

async function loadApplication(config) {
  const timings = {};
  const manifestStarted = performance.now();
  const manifest = validateApplicationManifest(
    await fetchJson(config.application_manifest_url, "Mobilis application manifest", { cache: "no-store" }),
    config.runtime
  );
  timings.applicationManifestMs = elapsed(manifestStarted);

  const archiveStarted = performance.now();
  const response = await fetchRequired(manifest.artifact.url, "Mobilis application archive", {
    cache: "force-cache",
    integrity: manifest.artifact.integrity
  });
  const archive = new Uint8Array(await response.arrayBuffer());
  await verifyBytes(archive, manifest.artifact, "Mobilis application archive");
  timings.applicationArchiveFetchAndVerifyMs = elapsed(archiveStarted);

  const unpackStarted = performance.now();
  const files = readTar(archive);
  await validateApplicationFiles(files, manifest.filesystem.files);
  timings.applicationUnpackAndVerifyMs = elapsed(unpackStarted);
  return { manifest, files, archiveBytes: archive.byteLength, timings };
}

async function fetchJson(url, label, options) {
  const response = await fetchRequired(url, label, options);
  try {
    return await response.json();
  } catch (error) {
    throw new Error(`${label} is not valid JSON: ${error.message}`, { cause: error });
  }
}

async function fetchRequired(url, label, options = {}) {
  let response;
  try {
    response = await fetch(url, options);
  } catch (error) {
    throw new Error(`Unable to load ${label} from ${url}: ${error.message}`, { cause: error });
  }
  if (!response.ok) throw new Error(`Unable to load ${label} from ${url}: HTTP ${response.status}`);
  return response;
}

function validateRuntimeConfig(config) {
  if (config?.format !== "mobilis-browser-runtime" || config?.version !== 1) {
    throw new Error("Unsupported or malformed Mobilis runtime configuration");
  }
  const runtime = config.runtime;
  if (!runtime || runtime.package !== "mobilis-ruby-wasm" || runtime.package_version !== "2.10.1-ruby-4.0.10-rails-8.1.4.1" || runtime.ruby_version !== "4.0") {
    throw new Error("Runtime configuration is not compatible with Mobilis's pinned Ruby 4.0 WASM runtime");
  }
  validateIntegrityRecord(runtime, "Ruby WASM runtime");
  if (typeof runtime.url !== "string" || !runtime.url) throw new Error("Ruby WASM runtime URL is missing");
  if (typeof config.application_manifest_url !== "string" || !config.application_manifest_url) {
    throw new Error("Mobilis application manifest URL is missing");
  }
  return config;
}

function validateApplicationManifest(manifest, runtime) {
  if (manifest?.format !== "mobilis-browser-application" || manifest?.version !== 1) {
    throw new Error("Unsupported or malformed Mobilis application manifest");
  }
  const compatible = manifest.compatible_runtime;
  if (compatible?.package !== runtime.package || compatible?.package_version !== runtime.package_version) {
    throw new Error(`Mobilis application ${manifest.application_version || "(unknown)"} is incompatible with ${runtime.package}@${runtime.package_version}`);
  }
  validateIntegrityRecord(manifest.artifact, "Mobilis application archive");
  if (typeof manifest.artifact.url !== "string" || !manifest.artifact.url) throw new Error("Mobilis application archive URL is missing");
  if (!manifest.filesystem || !Array.isArray(manifest.filesystem.load_paths) || !Array.isArray(manifest.filesystem.files)) {
    throw new Error("Mobilis application filesystem manifest is malformed");
  }
  if (!manifest.filesystem.load_paths.every(path => typeof path === "string" && safeAbsolutePath(path))) {
    throw new Error("Mobilis application manifest contains an unsafe load path");
  }
  if (typeof manifest.filesystem.boot_feature !== "string" || !manifest.filesystem.boot_feature) {
    throw new Error("Mobilis application boot feature is missing");
  }
  return manifest;
}

function validateIntegrityRecord(record, label) {
  if (!record || !Number.isSafeInteger(record.size) || record.size < 0 || !/^[a-f0-9]{64}$/.test(record.sha256 || "")) {
    throw new Error(`${label} integrity metadata is malformed`);
  }
  if (record.integrity !== `sha256-${hexToBase64(record.sha256)}`) {
    throw new Error(`${label} integrity metadata is inconsistent`);
  }
}

async function verifyBytes(bytes, record, label) {
  if (bytes.byteLength !== record.size) throw new Error(`${label} size mismatch: expected ${record.size}, received ${bytes.byteLength}`);
  const actual = await sha256Hex(bytes);
  if (actual !== record.sha256) throw new Error(`${label} integrity check failed`);
}

function readTar(archive) {
  const blockSize = 512;
  if (archive.byteLength < blockSize * 2 || archive.byteLength % blockSize !== 0) {
    throw new Error("Mobilis application archive is not a complete tar stream");
  }
  const files = new Map();
  let offset = 0;
  let terminated = false;
  while (offset + blockSize <= archive.byteLength) {
    const header = archive.subarray(offset, offset + blockSize);
    offset += blockSize;
    if (allZero(header)) {
      const second = archive.subarray(offset, offset + blockSize);
      if (second.byteLength !== blockSize || !allZero(second)) throw new Error("Mobilis application archive has an incomplete terminator");
      offset += blockSize;
      terminated = true;
      break;
    }
    validateTarHeader(header);
    const name = tarText(header.subarray(0, 100));
    const prefix = tarText(header.subarray(345, 500));
    const path = prefix ? `${prefix}/${name}` : name;
    if (!safeRelativePath(path)) throw new Error(`Mobilis application archive contains unsafe path ${JSON.stringify(path)}`);
    if (files.has(path)) throw new Error(`Mobilis application archive contains duplicate path ${path}`);
    const type = header[156];
    if (type !== 0 && type !== 48) throw new Error(`Mobilis application archive contains unsupported entry type for ${path}`);
    const size = tarOctal(header.subarray(124, 136), `size for ${path}`);
    const padded = Math.ceil(size / blockSize) * blockSize;
    if (offset + padded > archive.byteLength) throw new Error(`Mobilis application archive member is truncated: ${path}`);
    files.set(path, archive.slice(offset, offset + size));
    offset += padded;
  }
  if (!terminated) throw new Error("Mobilis application archive has no terminator");
  if (!allZero(archive.subarray(offset))) throw new Error("Mobilis application archive contains trailing data");
  return files;
}

function validateTarHeader(header) {
  if (tarText(header.subarray(257, 263)) !== "ustar") throw new Error("Mobilis application archive must use ustar headers");
  const expected = tarOctal(header.subarray(148, 156), "header checksum");
  let actual = 0;
  for (let index = 0; index < header.length; index += 1) actual += index >= 148 && index < 156 ? 32 : header[index];
  if (actual !== expected) throw new Error("Mobilis application archive header checksum mismatch");
}

async function validateApplicationFiles(files, records) {
  if (records.length !== files.size) throw new Error("Mobilis application manifest does not match archive members");
  const seen = new Set();
  await Promise.all(records.map(async record => {
    if (!record || !safeRelativePath(record.path) || seen.has(record.path)) throw new Error("Mobilis application manifest contains an unsafe or duplicate path");
    seen.add(record.path);
    const content = files.get(record.path);
    if (!content) throw new Error(`Mobilis application archive is missing ${record.path}`);
    if (!Number.isSafeInteger(record.size) || content.byteLength !== record.size) throw new Error(`Mobilis application file size mismatch: ${record.path}`);
    if (!/^[a-f0-9]{64}$/.test(record.sha256 || "") || await sha256Hex(content) !== record.sha256) {
      throw new Error(`Mobilis application file integrity check failed: ${record.path}`);
    }
  }));
}

function hydrateFilesystem(files) {
  const root = new Directory(new Map());
  root.contents.set("tmp", new Directory(new Map()));
  root.contents.get("tmp").parent = root;

  for (const [path, bytes] of files) {
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
    directory.contents.set(filename, new File(bytes));
  }

  return root;
}

function safeRelativePath(path) {
  return typeof path === "string" && path.length > 0 && !path.startsWith("/") && !path.includes("\\") && !path.includes("\0") &&
    path.split("/").every(component => component && component !== "." && component !== "..");
}

function safeAbsolutePath(path) {
  return path.startsWith("/") && safeRelativePath(path.slice(1));
}

function tarText(bytes) {
  const end = bytes.indexOf(0);
  return new TextDecoder("utf-8", { fatal: true }).decode(end === -1 ? bytes : bytes.subarray(0, end));
}

function tarOctal(bytes, label) {
  const value = tarText(bytes).trim();
  if (!/^[0-7]+$/.test(value)) throw new Error(`Mobilis application archive has invalid ${label}`);
  return Number.parseInt(value, 8);
}

function allZero(bytes) {
  return bytes.every(byte => byte === 0);
}

async function sha256Hex(bytes) {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return Array.from(digest, byte => byte.toString(16).padStart(2, "0")).join("");
}

function hexToBase64(hex) {
  const bytes = Uint8Array.from(hex.match(/../g) || [], pair => Number.parseInt(pair, 16));
  return btoa(String.fromCharCode(...bytes));
}

function elapsed(started) {
  return performance.now() - started;
}

function escapeHtml(value) {
  const node = document.createElement("div");
  node.textContent = value;
  return node.innerHTML;
}

boot();
