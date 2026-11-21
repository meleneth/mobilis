const WORKSPACE_DIRECTORY = "/workspace";
const SOURCE_PATH = "mobilis.rb";
const LAST_VALID_PATH = ".mobilis/last-valid.rb";
const GITIGNORE = ".mobilis/\n";
const AUTHOR = { name: "Mobilis Playground", email: "playground@mobilis.local" };

export function createWorkspaceController() {
  const fs = new window.LightningFS("mobilis-workspace-v1");
  const pfs = fs.promises;
  let queue = Promise.resolve();
  let initialized = false;
  let attached = false;
  let selectedPath = null;

  const controller = {
    bootstrapSource: "",
    bootstrapValidSource: "",
    hasBootstrapSource: false,

    async initialize() {
      await mkdirp(WORKSPACE_DIRECTORY);
      await mkdirp(path(LAST_VALID_PATH, true));
      if (!(await exists(`${WORKSPACE_DIRECTORY}/.git`))) {
        await window.git.init({ fs, dir: WORKSPACE_DIRECTORY, defaultBranch: "main" });
      }
      controller.bootstrapSource = await readTextIfPresent(SOURCE_PATH);
      controller.bootstrapValidSource = await readTextIfPresent(LAST_VALID_PATH);
      controller.hasBootstrapSource = controller.bootstrapSource.length > 0;
      initialized = true;
      return controller;
    },

    attach() {
      if (attached) return;
      attached = true;
      bindControls();
      controller.refresh();
    },

    persistSource(source, valid) {
      return enqueue(async () => {
        await writeTextIfChanged(SOURCE_PATH, source);
        await writeTextIfChanged(".gitignore", GITIGNORE);
        if (valid) await writeTextIfChanged(LAST_VALID_PATH, source);
        await ensureInitialCommit();
        await flush();
        if (attached) await refreshView();
      });
    },

    persistGenerated(serializedFiles) {
      return enqueue(async () => {
        const files = JSON.parse(serializedFiles);
        const destination = `${WORKSPACE_DIRECTORY}/generate`;
        const temporary = `${WORKSPACE_DIRECTORY}/.mobilis/generate-next`;
        const backup = `${WORKSPACE_DIRECTORY}/.mobilis/generate-previous`;
        await removeTree(temporary);
        await removeTree(backup);
        await mkdirp(temporary);
        for (const name of Object.keys(files).sort()) {
          validateRelativePath(name);
          const target = `${temporary}/${name}`;
          await mkdirp(parent(target));
          await pfs.writeFile(target, decodeBase64(files[name]));
        }
        const hadDestination = await exists(destination);
        if (hadDestination) await pfs.rename(destination, backup);
        try {
          await pfs.rename(temporary, destination);
        } catch (error) {
          if (hadDestination && await exists(backup)) await pfs.rename(backup, destination);
          throw error;
        }
        await removeTree(backup);
        await flush();
        if (attached) await refreshView();
      });
    },

    applyCompatibility(root, button = document.getElementById("apply-generator-compatibility")) {
      return enqueue(() => applyCompatibility(root, button));
    },

    refresh() {
      return enqueue(refreshView);
    },

    flushPending() {
      return queue.then(flush);
    }
  };

  function enqueue(operation) {
    queue = queue.catch(() => {}).then(async () => {
      if (!initialized) await controller.initialize();
      try {
        await operation();
        showError("");
      } catch (error) {
        showError(error.message || String(error));
        throw error;
      }
    });
    return queue;
  }

  function bindControls() {
    const runUiOperation = operation => { void enqueue(operation).catch(() => {}); };
    document.getElementById("workspace-refresh")?.addEventListener("click", () => runUiOperation(refreshView));
    document.getElementById("workspace-stage")?.addEventListener("click", () => runUiOperation(stageAll));
    document.getElementById("workspace-commit")?.addEventListener("click", () => runUiOperation(commit));
    document.getElementById("apply-generator-compatibility")?.addEventListener("click", event => {
      const root = document.getElementById("compatibility-root")?.value.trim() || "";
      runUiOperation(() => applyCompatibility(root, event.currentTarget));
    });
    document.getElementById("workspace-files")?.addEventListener("click", event => {
      const button = event.target.closest("button[data-path]");
      if (!button) return;
      selectedPath = button.dataset.path;
      runUiOperation(refreshView);
    });
    document.getElementById("workspace-history")?.addEventListener("click", event => {
      const button = event.target.closest("button[data-oid]");
      if (!button) return;
      runUiOperation(() => checkout(button.dataset.oid));
    });
  }

  async function ensureInitialCommit() {
    if (await hasHead()) return;
    await window.git.add({ fs, dir: WORKSPACE_DIRECTORY, filepath: SOURCE_PATH });
    await window.git.add({ fs, dir: WORKSPACE_DIRECTORY, filepath: ".gitignore" });
    await window.git.commit({
      fs,
      dir: WORKSPACE_DIRECTORY,
      message: "Initialize Mobilis project",
      author: AUTHOR
    });
  }

  async function stageAll() {
    const matrix = await statusMatrix();
    for (const [filepath, , worktree] of matrix) {
      if (worktree === 0) {
        await window.git.remove({ fs, dir: WORKSPACE_DIRECTORY, filepath });
      } else {
        await window.git.add({ fs, dir: WORKSPACE_DIRECTORY, filepath });
      }
    }
    await flush();
    await refreshView();
  }

  async function commit() {
    const input = document.getElementById("workspace-commit-message");
    const message = input?.value.trim() || "";
    if (!message) throw new Error("Enter a commit message before committing.");
    const matrix = await statusMatrix();
    if (!matrix.some(([, head, , stage]) => head !== stage)) {
      throw new Error("There are no staged changes to commit.");
    }
    await window.git.commit({ fs, dir: WORKSPACE_DIRECTORY, message, author: AUTHOR });
    if (input) input.value = "";
    await flush();
    await refreshView();
  }

  async function checkout(oid) {
    const matrix = await statusMatrix();
    if (matrix.some(([, head, worktree, stage]) => !(head === 1 && worktree === 1 && stage === 1))) {
      throw new Error("Commit or discard working-tree changes before restoring a revision.");
    }
    if (window.MobilisDocuments?.hasUnsavedChanges()) {
      throw new Error("Save or discard the open embedded document before restoring a revision.");
    }

    const previous = await window.git.resolveRef({ fs, dir: WORKSPACE_DIRECTORY, ref: "HEAD" });
    await window.git.checkout({ fs, dir: WORKSPACE_DIRECTORY, ref: oid, noUpdateHead: true, force: true, nonBlocking: true });
    try {
      const source = await readTextIfPresent(SOURCE_PATH);
      if (!source) throw new Error("The selected revision does not contain mobilis.rb.");
      const detail = { source, accepted: false, valid: false, error: null };
      document.dispatchEvent(new CustomEvent("mobilis:workspace-checkout", { detail }));
      if (!detail.accepted) throw new Error(detail.error || "Ruby rejected the checked-out project.");
      await writeTextIfChanged(LAST_VALID_PATH, source);
    } catch (error) {
      await window.git.checkout({ fs, dir: WORKSPACE_DIRECTORY, ref: previous, noUpdateHead: true, force: true, nonBlocking: true });
      throw new Error(`Checkout was rolled back: ${error.message || String(error)}`);
    }
    await flush();
    await refreshView();
  }

  async function applyCompatibility(root, button) {
    validateRelativePath(root);
    if (!button) throw new Error("Generator compatibility control is unavailable.");

    const inputPaths = JSON.parse(button.dataset.inputPaths || "[]");
    const argumentsList = JSON.parse(button.dataset.arguments || "[]");
    const files = {};
    for (const relative of inputPaths) {
      validateRelativePath(relative);
      const bytes = await readBytesIfPresent(`${root}/${relative}`);
      files[relative] = bytes ? encodeBase64(bytes) : null;
    }

    const detail = {
      request: JSON.stringify({
        generator: button.dataset.generator,
        version: button.dataset.version,
        arguments: argumentsList,
        files
      }),
      accepted: false,
      response: null,
      error: null
    };
    document.dispatchEvent(new CustomEvent("mobilis:generator-compatibility", { detail }));
    if (!detail.accepted) throw new Error(detail.error || "Ruby rejected the generator compatibility request.");

    const plan = JSON.parse(detail.response);
    for (const relative of inputPaths) {
      const current = await readBytesIfPresent(`${root}/${relative}`);
      const encoded = current ? encodeBase64(current) : null;
      if (encoded !== files[relative]) {
        throw new Error(`Workspace changed while preparing compatibility operation: ${relative}`);
      }
    }

    const writes = Object.entries(plan.writes || {}).sort(([left], [right]) => left.localeCompare(right));
    const backups = new Map();
    try {
      for (const [relative, record] of writes) {
        validateRelativePath(relative);
        const target = `${root}/${relative}`;
        backups.set(target, await readBytesIfPresent(target));
        await mkdirp(parent(`${WORKSPACE_DIRECTORY}/${target}`));
        await pfs.writeFile(`${WORKSPACE_DIRECTORY}/${target}`, decodeBase64(record.content));
      }
    } catch (error) {
      for (const [target, previous] of [...backups.entries()].reverse()) {
        if (previous) {
          await pfs.writeFile(`${WORKSPACE_DIRECTORY}/${target}`, previous);
        } else if (await exists(`${WORKSPACE_DIRECTORY}/${target}`)) {
          await pfs.unlink(`${WORKSPACE_DIRECTORY}/${target}`);
        }
      }
      throw error;
    }

    await flush();
    const status = document.getElementById("compatibility-status");
    if (status) {
      const created = plan.created?.length || 0;
      const unchanged = plan.unchanged?.length || 0;
      status.textContent = `Applied ${button.dataset.generator} ${button.dataset.version}: ${created} created, ${unchanged} unchanged.`;
    }
    await refreshView();
  }

  async function refreshView() {
    if (!attached) return;
    const matrix = await statusMatrix();
    const changed = matrix.filter(([, head, worktree, stage]) => !(head === 1 && worktree === 1 && stage === 1));
    const summary = document.getElementById("workspace-summary");
    if (summary) summary.textContent = changed.length === 0 ? "Clean working tree" : `${changed.length} changed file${changed.length === 1 ? "" : "s"}`;
    renderChangedFiles(changed);
    await renderHistory();
    await renderDiff(changed);
  }

  function renderChangedFiles(changed) {
    const target = document.getElementById("workspace-files");
    if (!target) return;
    target.replaceChildren();
    if (changed.length === 0) {
      target.append(textElement("p", "No changes."));
      selectedPath = null;
      return;
    }
    if (!changed.some(([filepath]) => filepath === selectedPath)) selectedPath = changed[0][0];
    for (const [filepath, head, worktree, stage] of changed) {
      const button = textElement("button", `${statusLabel(head, worktree, stage)} ${filepath}`);
      button.type = "button";
      button.dataset.path = filepath;
      button.className = `block w-full rounded px-2 py-1 text-left hover:bg-slate-800 ${filepath === selectedPath ? "bg-slate-800 text-white" : ""}`;
      target.append(button);
    }
  }

  async function renderHistory() {
    const target = document.getElementById("workspace-history");
    if (!target) return;
    target.replaceChildren();
    if (!(await hasHead())) {
      target.append(textElement("p", "No commits yet."));
      return;
    }
    const entries = await window.git.log({ fs, dir: WORKSPACE_DIRECTORY, depth: 20 });
    for (const entry of entries) {
      const row = document.createElement("div");
      row.className = "rounded border border-line p-2";
      const message = textElement("p", entry.commit.message.trim().split("\n")[0]);
      message.className = "truncate text-slate-200";
      const meta = textElement("p", entry.oid.slice(0, 8));
      meta.className = "mt-1 text-[10px] text-slate-500";
      const restore = textElement("button", "Restore");
      restore.type = "button";
      restore.dataset.oid = entry.oid;
      restore.className = "mt-2 text-teal-300 hover:text-teal-200";
      row.append(message, meta, restore);
      target.append(row);
    }
  }

  async function renderDiff(changed) {
    const target = document.getElementById("workspace-diff");
    if (!target) return;
    if (!selectedPath || !changed.some(([filepath]) => filepath === selectedPath)) {
      target.textContent = "Select a changed file to inspect it.";
      return;
    }
    const before = await readHeadFile(selectedPath);
    const after = await readBytesIfPresent(selectedPath);
    target.textContent = lineDiff(selectedPath, before, after);
  }

  async function readHeadFile(filepath) {
    if (!(await hasHead())) return null;
    try {
      const result = await window.git.readBlob({ fs, dir: WORKSPACE_DIRECTORY, oid: "HEAD", filepath });
      return result.blob;
    } catch (error) {
      if (error.code === "NotFoundError" || error.code === "ResolveTreeError") return null;
      throw error;
    }
  }

  function statusMatrix() {
    return window.git.statusMatrix({ fs, dir: WORKSPACE_DIRECTORY });
  }

  async function hasHead() {
    try {
      await window.git.resolveRef({ fs, dir: WORKSPACE_DIRECTORY, ref: "HEAD" });
      return true;
    } catch (error) {
      if (error.code === "NotFoundError" || error.code === "ResolveRefError") return false;
      throw error;
    }
  }

  async function readTextIfPresent(relative) {
    const bytes = await readBytesIfPresent(relative);
    return bytes ? new TextDecoder().decode(bytes) : "";
  }

  async function readBytesIfPresent(relative) {
    try {
      return new Uint8Array(await pfs.readFile(`${WORKSPACE_DIRECTORY}/${relative}`));
    } catch (error) {
      if (error.code === "ENOENT") return null;
      throw error;
    }
  }

  async function writeTextIfChanged(relative, content) {
    const encoded = new TextEncoder().encode(content);
    const current = await readBytesIfPresent(relative);
    if (current && bytesEqual(current, encoded)) return false;
    const target = `${WORKSPACE_DIRECTORY}/${relative}`;
    await mkdirp(parent(target));
    await pfs.writeFile(target, encoded);
    return true;
  }

  async function mkdirp(directory) {
    if (!directory || directory === "/") return;
    try {
      await pfs.mkdir(directory);
    } catch (error) {
      if (error.code === "ENOENT") {
        await mkdirp(parent(directory));
        await pfs.mkdir(directory);
      } else if (error.code !== "EEXIST") {
        throw error;
      }
    }
  }

  async function removeTree(target) {
    let stat;
    try {
      stat = await pfs.stat(target);
    } catch (error) {
      if (error.code === "ENOENT") return;
      throw error;
    }
    if (!stat.isDirectory()) {
      await pfs.unlink(target);
      return;
    }
    for (const entry of await pfs.readdir(target)) await removeTree(`${target}/${entry}`);
    await pfs.rmdir(target);
  }

  async function exists(target) {
    try {
      await pfs.stat(target);
      return true;
    } catch (error) {
      if (error.code === "ENOENT") return false;
      throw error;
    }
  }

  async function flush() {
    if (typeof pfs.flush === "function") await pfs.flush();
  }

  function showError(message) {
    const target = document.getElementById("workspace-error");
    if (!target) return;
    target.textContent = message;
    target.classList.toggle("hidden", !message);
  }

  return controller;
}

function lineDiff(filepath, beforeBytes, afterBytes) {
  if ((beforeBytes && !isText(beforeBytes)) || (afterBytes && !isText(afterBytes))) {
    return `Binary file changed: ${filepath}`;
  }
  const before = beforeBytes ? new TextDecoder().decode(beforeBytes).split("\n") : [];
  const after = afterBytes ? new TextDecoder().decode(afterBytes).split("\n") : [];
  let prefix = 0;
  while (prefix < before.length && prefix < after.length && before[prefix] === after[prefix]) prefix += 1;
  let suffix = 0;
  while (suffix < before.length - prefix && suffix < after.length - prefix && before[before.length - 1 - suffix] === after[after.length - 1 - suffix]) suffix += 1;
  const contextStart = Math.max(0, prefix - 3);
  const beforeEnd = before.length - suffix;
  const afterEnd = after.length - suffix;
  const contextEndBefore = Math.min(before.length, beforeEnd + 3);
  const contextEndAfter = Math.min(after.length, afterEnd + 3);
  const lines = [`--- a/${filepath}`, `+++ b/${filepath}`];
  for (const line of before.slice(contextStart, prefix)) lines.push(` ${line}`);
  for (const line of before.slice(prefix, beforeEnd)) lines.push(`-${line}`);
  for (const line of after.slice(prefix, afterEnd)) lines.push(`+${line}`);
  const trailing = after.slice(afterEnd, contextEndAfter);
  if (trailing.length === 0 && beforeEnd < contextEndBefore) {
    for (const line of before.slice(beforeEnd, contextEndBefore)) lines.push(` ${line}`);
  } else {
    for (const line of trailing) lines.push(` ${line}`);
  }
  return lines.join("\n");
}

function isText(bytes) {
  if (bytes.includes(0)) return false;
  try {
    new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    return true;
  } catch (_error) {
    return false;
  }
}

function statusLabel(head, worktree, stage) {
  if (head === 0 && worktree !== 0) return "??";
  if (worktree === 0) return "D ";
  if (head !== stage) return "M+";
  return " M";
}

function validateRelativePath(value) {
  if (!value || value.startsWith("/") || value.split("/").some(part => part === ".." || part === "")) {
    throw new Error(`Unsafe generated file path: ${value}`);
  }
}

function decodeBase64(value) {
  return Uint8Array.from(atob(value), character => character.charCodeAt(0));
}

function encodeBase64(bytes) {
  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

function bytesEqual(left, right) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function path(value, directory = false) {
  const full = `${WORKSPACE_DIRECTORY}/${value}`;
  return directory ? parent(full) : full;
}

function parent(value) {
  const index = value.lastIndexOf("/");
  return index <= 0 ? "/" : value.slice(0, index);
}

function textElement(tag, content) {
  const element = document.createElement(tag);
  element.textContent = content;
  return element;
}
