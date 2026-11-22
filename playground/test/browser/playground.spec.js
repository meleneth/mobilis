import { expect, test } from "@playwright/test";
import { ZipReader, BlobReader, Uint8ArrayWriter } from "@zip.js/zip.js";
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { execFileSync } from "node:child_process";

test("catalog exposes every packaged numbered example and preserves exact bytes", async ({ page }) => {
  const catalog = await (await page.request.get("/examples/index.json")).json();
  const options = page.getByLabel("Load numbered example").locator("option");
  expect(catalog.length).toBeGreaterThanOrEqual(26);
  await expect(options).toHaveCount(catalog.length + 1);
  for (const entry of catalog) {
    expect(entry.file).toMatch(/^[0-9]{2}_[a-z0-9_]+\\.rb$/);
    expect((await page.request.get(`/examples/${entry.file}`)).ok()).toBe(true);
  }
});

test("example choice asks for confirmation and cancellation preserves the authored DSL", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const source = await editor.inputValue();
  page.once("dialog", async dialog => {
    expect(dialog.message()).toMatch(/Are you sure/);
    await dialog.dismiss();
  });
  await page.getByLabel("Load numbered example").selectOption("01_mobilis_initial_system.rb");
  await expect(editor).toHaveValue(source);
  await expect(page.getByLabel("Load numbered example")).toHaveValue("");
});

test("confirmed numbered example replaces source without propagating unrelated service renames", async ({ page }) => {
  const name = "01_mobilis_initial_system.rb";
  const raw = await (await page.request.get(`/examples/${name}`)).text();
  page.once("dialog", dialog => dialog.accept());
  await page.getByLabel("Load numbered example").selectOption(name);
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(raw);
  await expect(page.getByLabel("Load numbered example")).toHaveValue("");
});

test.beforeEach(async ({ page }) => {
  page.on("console", message => console.log(`[browser:${message.type()}] ${message.text()}`));
  page.on("pageerror", error => console.error(`[browser:error] ${error.stack || error}`));
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Mobilis Browser Playground" })).toBeVisible({ timeout: 120_000 });
});

test("system starting port round-trips through the builder and DSL", async ({ page }) => {
  const port = page.getByRole("spinbutton", { name: "Starting port" });
  const editor = page.getByLabel("Mobilis Ruby DSL");

  await expect(port).toHaveValue("11000");
  await port.fill("12000");
  await port.blur();
  await expect(editor).toHaveValue(/starting_port: 12000/);
  await expect(page.getByRole("spinbutton", { name: "Starting port" })).toHaveValue("12000");
  await expect(page.locator("#diagnostics-region")).toContainText("Visual edit applied");

  await editor.fill((await editor.inputValue()).replace("starting_port: 12000", "starting_port: 13000"));
  await expect(page.getByRole("spinbutton", { name: "Starting port" })).toHaveValue("13000");
});

test("system port control inserts an omitted default and refuses to rewrite dynamic Ruby", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  await editor.fill((await editor.inputValue()).replace(", starting_port: 11_000", ""));
  await expect(page.getByRole("spinbutton", { name: "Starting port" })).toHaveValue("11000");
  await page.getByRole("spinbutton", { name: "Starting port" }).fill("14500");
  await page.getByRole("spinbutton", { name: "Starting port" }).blur();
  await expect(editor).toHaveValue(/generate\("browser-demo", starting_port: 14500\)/);

  await editor.fill((await editor.inputValue()).replace("starting_port: 14500", "starting_port: 14_000 + 500"));
  await expect(page.getByRole("spinbutton", { name: "Starting port" })).toBeDisabled();
});

test("form typing updates the Ruby source, inspector and Mermaid without blurring", async ({ page }) => {
  const name = page.locator(".service-card .service-name").nth(1);
  await name.click();
  await name.press("End");
  await name.press("x");
  await expect(name).toBeFocused();
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(/redis\("cachex"\)/);
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(/connect\(from: "cachex", to: "database"\)/);
  await expect(page.locator("#service-inspector-panels")).toContainText("cachex");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cachex");
  await name.press("y");
  await expect(name).toBeFocused();
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(/redis\("cachexy"\)/);
});

test("one typed DSL character renames all bound service literals and updates projections", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  await expect(editor).toHaveValue(/redis\("cache"\)/);

  // Unlike fill(), this fires a real keystroke input event with a caret
  // inside the declaration while preserving all other source bytes.
  await editor.evaluate(element => {
    const start = element.value.indexOf('redis("cache")') + 'redis("ca'.length;
    element.focus();
    element.setSelectionRange(start, start);
  });
  await editor.press("n");

  await expect(editor).toHaveValue(/redis\("canche"\)/);
  await expect(editor).toHaveValue(/connect\(from: "canche", to: "database"\)/);
  await expect(page.locator(".service-card .service-name").nth(1)).toHaveValue("canche");
  await expect(page.locator("#service-inspector-panels")).toContainText("canche");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: canche");
  await expect(page.locator("#architecture-region")).toContainText("Live from validated DSL");
});

test("the left service field never diverges from DSL after an in-place rename", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const initial = await editor.inputValue();
  await editor.fill(initial.replaceAll('"cache"', '"casz"'));
  const name = page.locator(".service-card .service-name").nth(1);
  await expect(name).toHaveValue("casz");

  await name.fill("cas2");
  await expect(editor).toHaveValue(/redis\("cas2"\)/);
  await expect(editor).toHaveValue(/connect\(from: "cas2", to: "database"\)/);
  await expect(page.locator(".service-card .service-name").nth(1)).toHaveValue("cas2");
  await expect(page.locator("#service-inspector-panels")).toContainText("cas2");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cas2");
  await expect(page.locator("#diagnostics-region")).toContainText("Visual edit applied");
});

test("inspector property editing updates the DSL before blur", async ({ page }) => {
  await page.getByLabel("New service name").fill("api");
  await page.locator("#new-service-type").selectOption("rails");
  await page.getByRole("button", { name: "Add service" }).click();
  const card = page.locator(".service-card").filter({ has: page.locator('.service-name[value="api"]') });
  await card.locator(".select-service").click();
  const inspector = page.locator(".service-inspector:not(.hidden)");
  const control = inspector.locator('.inspector-service-property[data-property="api"]');
  await control.check();
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(/rails\("api", api: true\)/);
});

test("keeps repeated DSL string literals synchronized without requiring a Ruby variable", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const initial = await editor.inputValue();
  // An independent literal in the DSL body is an implicit reference, but
  // strings outside the block and the project identifier are not.
  const withAlias = initial.replace('redis("cache")', 'redis("cache")\n  label = "cache"');
  await editor.fill(withAlias);
  await expect(page.locator("#diagnostics-region")).toContainText("Source is valid");

  await editor.fill(withAlias.replace('redis("cache")', 'redis("canhe")'));
  await expect(editor).toHaveValue(/redis\("canhe"\)/);
  await expect(editor).toHaveValue(/label = "canhe"/);
  await expect(editor).toHaveValue(/connect\(from: "canhe", to: "database"\)/);
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: canhe");
});

test("synchronizes visual and Ruby editing, including Rails authoring", async ({ page }) => {
  await page.getByLabel("New service name").fill("web");
  await page.locator("#new-service-type").selectOption("rails");
  await page.getByRole("button", { name: "Add service" }).click();

  const editor = page.getByLabel("Mobilis Ruby DSL");
  await expect(editor).toHaveValue(/rails\("web"\)/);
  const railsCard = page.locator(".service-card").filter({ has: page.locator('.service-name[value="web"]') });
  await expect(railsCard).toContainText("Local generation");
  await expect(page.locator("#architecture-region")).toContainText("3 nodes · 1 edges");
  await expect(page.locator("#architecture-canvas .node").filter({ hasText: "Rails: web" })).toBeVisible();

  await editor.fill((await editor.inputValue()).replaceAll('"cache"', '"session-cache"'));
  await expect(page.locator(".service-name").nth(1)).toHaveValue("session-cache");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: session-cache");
});

test("preserves the last visual model while invalid Ruby is repaired", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const valid = await editor.inputValue();
  const cardCount = await page.locator(".service-card").count();

  await editor.fill("Mobilis::DSL.generate(");
  await expect(page.locator("#diagnostics-region")).toContainText("Source or generation error");
  await expect(page.locator(".service-card")).toHaveCount(cardCount);
  await expect(page.locator("#architecture-region")).toContainText("Stale — source is invalid");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cache");

  await editor.fill(valid);
  await expect(page.locator("#diagnostics-region")).toContainText("Source is valid");
  await expect(page.locator("#architecture-region")).toContainText("Live from validated DSL");
});

test("with reference synchronization disabled, a partial rename exposes stale projections", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  await page.locator("#sync-service-renames").uncheck();
  const original = await editor.inputValue();
  // A valid Ruby string edit is not necessarily a valid Mobilis system.
  // The connection still references 'cache' after the declaration becomes 'cach'.
  const inconsistent = original.replace('redis("cache")', 'redis("cach")');
  await editor.fill(inconsistent);

  await expect(page.locator("#diagnostics-region")).toContainText("Source or generation error");
  await expect(page.locator("#builder-region [data-projection-state=stale]")).toBeVisible();
  await expect(page.locator("#inspector-region [data-projection-state=stale]")).toBeVisible();
  await expect(page.locator("#architecture-region")).toContainText("Stale");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cache");

  // Once both source references agree, every projection must catch up.
  await editor.fill(inconsistent.replace('from: "cache"', 'from: "cach"'));
  await expect(page.locator("#builder-region [data-projection-state=stale]")).toHaveCount(0);
  await expect(page.locator("#inspector-region [data-projection-state=stale]")).toHaveCount(0);
  await expect(page.locator(".service-name").nth(1)).toHaveValue("cach");
  await expect(page.locator("#service-inspector-panels")).toContainText("cach");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cach");
});

test("syncs a single character inserted into a service declaration and its references", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const initial = await editor.inputValue();
  expect(await page.locator("#sync-service-renames").isChecked()).toBe(true);
  const renamed = initial.replace('redis("cache")', 'redis("canche")');
  await editor.fill(renamed);
  await expect(editor).toHaveValue(/redis\("canche"\)/);
  await expect(editor).toHaveValue(/connect\(from: "canche", to: "database"\)/);
  await expect(page.locator(".service-name").nth(1)).toHaveValue("canche");
  await expect(page.locator("#service-inspector-panels")).toContainText("canche");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: canche");
  await expect(page.locator("#architecture-region")).toContainText("Live from validated DSL");

  await page.locator("#sync-service-renames").uncheck();
  await editor.fill((await editor.inputValue()).replace('redis("canche")', 'redis("canche2")'));
  await expect(editor).toHaveValue(/connect\(from: "canche", to: "database"\)/);
  await expect(page.locator("#architecture-region")).toContainText("Stale");
});

test("does not rewrite unrelated equal strings during service rename", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const source = await editor.inputValue();
  await editor.fill(source.replace('"browser-demo"', '"cache"'));
  await expect(page.locator("#diagnostics-region")).toContainText("Source is valid");
  await editor.fill((await editor.inputValue()).replace('redis("cache")', 'redis("cache2")'));
  await expect(editor).toHaveValue(/generate\("cache"/);
  await expect(editor).toHaveValue(/connect\(from: "cache2", to: "database"\)/);
});


test("removes connected nodes and edges through the visual builder", async ({ page }) => {
  const cacheCard = page.locator(".service-card").filter({ has: page.locator('.service-name[value="cache"]') });
  await cacheCard.getByRole("button", { name: "Remove" }).click();

  await expect(page.locator("#architecture-region")).toContainText("1 nodes · 0 edges");
  await expect(page.locator("#architecture-canvas")).not.toContainText("Redis: cache");
  await expect(page.getByLabel("Mobilis Ruby DSL")).not.toHaveValue(/connect\(/);
});

test("selects a diagram node without mutating source", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const original = await editor.inputValue();
  const invocationCount = await rubyInvocationCount(page);
  await page.locator("#architecture-canvas .node").filter({ hasText: "PostgreSQL: database" }).click();

  const databaseCard = page.locator(".service-card").filter({ has: page.locator('.service-name[value="database"]') });
  await expect(databaseCard).toHaveClass(/diagram-selected/);
  expect(await editor.evaluate(element => element.value.slice(element.selectionStart, element.selectionEnd))).toContain('postgres("database")');
  await expect(editor).toHaveValue(original);
  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(250);
  expect(await rubyInvocationCount(page)).toBe(invocationCount);
  expect(await page.evaluate(() => window.MobilisRuntimeDiagnostics.vmInstances)).toBe(1);
});

test("boots a verified application artifact once and exposes initialization diagnostics", async ({ page }) => {
  const diagnostics = await page.evaluate(() => window.MobilisRuntimeDiagnostics);
  expect(diagnostics.phase).toBe("ready");
  // Ruby boot fails before declaring ready unless native JSON ABI matches.
  expect(diagnostics.vmInstances).toBe(1);
  expect(diagnostics.runtime.package).toBe("mobilis-ruby-wasm");
  expect(diagnostics.runtime.package_version).toBe("2.10.1-ruby-4.0.10-rails-8.1.4.1-json-3.1.0-single-ext");
  expect(diagnostics.application.files).toBeGreaterThan(300);
  expect(diagnostics.application.version).toMatch(/^[a-f0-9]{64}$/);
  expect(diagnostics.timings.runtimeCompileMs).toBeGreaterThan(0);
  expect(diagnostics.timings.rubyApplicationLoadMs).toBeGreaterThan(0);

  await page.getByLabel("New service name").fill("metrics-cache");
  await page.locator("#new-service-type").selectOption("redis");
  await page.getByRole("button", { name: "Add service" }).click();
  await expect(page.locator(".service-name")).toHaveCount(3);
  expect(await page.evaluate(() => window.MobilisRuntimeDiagnostics.vmInstances)).toBe(1);
});

test("edits relationships through the selected service inspector", async ({ page }) => {
  await page.getByLabel("New service name").fill("queue");
  await page.locator("#new-service-type").selectOption("redis");
  await page.getByRole("button", { name: "Add service" }).click();

  const cacheCard = page.locator(".service-card").filter({ has: page.locator('.service-name[value="cache"]') });
  await cacheCard.locator(".select-service").click();
  const inspector = page.locator(".service-inspector:not(.hidden)");
  await expect(inspector).toContainText("cache");
  await inspector.locator(".relationship-target").selectOption("queue");
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(/connect\(from: "cache", to: "queue"\)/);
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: queue");

  await inspector.locator(".remove-relationship").click();
  await expect(page.getByLabel("Mobilis Ruby DSL")).not.toHaveValue(/connect\(from: "cache"/);
  await expect(page.locator("#architecture-region")).toContainText("3 nodes · 0 edges");
});

test("browses, commits, reopens, undoes, and conflict-checks embedded documents", async ({ page }) => {
  const fixture = await page.evaluate(() => fetch("/parity/embedded-source.rb").then(response => response.text()));
  const rubyEditor = page.getByLabel("Mobilis Ruby DSL");
  await rubyEditor.fill(fixture);
  await expect(page.locator("#diagnostics-region")).toContainText("Source is valid");

  const archive = page.locator("details.embedded-archive");
  await archive.evaluate(element => { element.open = true; });
  const invocationCount = await rubyInvocationCount(page);
  await page.getByRole("button", { name: /README\.md/ }).click();
  expect(await rubyInvocationCount(page)).toBe(invocationCount);

  const embeddedEditor = page.getByLabel("Embedded document editor");
  await expect(embeddedEditor).toHaveValue("hello from the archive\n");
  await embeddedEditor.fill("edited in the browser\n");
  expect(await rubyInvocationCount(page)).toBe(invocationCount);
  await expect(page.locator("#embedded-document-state")).toContainText("Unsaved");
  await page.getByRole("button", { name: "Save into Ruby archive" }).click();
  await expect(rubyEditor).toBeVisible();
  await expect(rubyEditor).toHaveValue(/This comment and the second archive member/);
  expect(await rubyInvocationCount(page)).toBe(invocationCount + 1);

  await openEmbeddedMember(page, /README\.md/);
  await expect(page.getByLabel("Embedded document editor")).toHaveValue("edited in the browser\n");
  await page.getByRole("button", { name: "Return to Ruby" }).click();
  await page.getByRole("button", { name: /Undo embedded document edit/ }).click();
  await openEmbeddedMember(page, /README\.md/);
  await expect(page.getByLabel("Embedded document editor")).toHaveValue("hello from the archive\n");

  await page.getByLabel("Embedded document editor").fill("must not overwrite newer Ruby\n");
  await page.evaluate(() => {
    const editor = document.getElementById("dsl-source");
    editor.value = `# newer parent revision\n${editor.value}`;
    editor.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await expect(page.locator("#embedded-document-conflict")).toBeVisible();
  await page.getByRole("button", { name: "Save into Ruby archive" }).click();
  await expect(page.locator("#diagnostics-region")).toContainText("parent Ruby source changed");
  await expect(page.locator("#embedded-document-state")).toContainText("Save failed");
});

test("generates real files and navigates the read-only browser", async ({ page }) => {
  await page.getByRole("button", { name: "Generate project" }).click();
  await expect(page.locator("#diagnostics-region")).toContainText(/Generated \d+ files with \d+ committed Mobilis phases\. ZIP ready\./);

  await page.getByRole("button", { name: "compose/database.yml" }).click();
  const expected = await page.evaluate(() => fetch("/parity/postgres-compose.yml").then(response => response.text()));
  await expect(page.locator("#file-content-region pre")).toHaveText(expected);
  await expect(page.getByRole("button", { name: "Download ZIP" })).toBeVisible();

  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Download ZIP" }).click();
  const download = await downloadPromise;
  const bytes = await readDownload(download);
  expect(bytes.includes(Buffer.from("compose/database.yml"))).toBe(true);
  expect(bytes.includes(Buffer.from("development-compose.yml"))).toBe(true);
});

test("exports a generated Redis/PostgreSQL workspace with inspectable piecemeal Git history", async ({ page }) => {
  // Real workspace Git objects must survive the ZIP, not merely the final
  // generated files. This is an infrastructure-generation acceptance test;
  // Rails application generation requires the separate native pipeline.
  const editor = page.getByLabel("Mobilis Ruby DSL");
  await editor.fill((await editor.inputValue()).replaceAll('"cache"', '"session-cache"'));
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: session-cache");
  await page.getByRole("button", { name: "Stage all" }).click();
  await page.getByLabel("Git commit message").fill("Rename Redis service");
  await page.getByRole("button", { name: "Commit staged changes" }).click();
  await expect(page.locator("#workspace-history")).toContainText("Rename Redis service");

  await page.getByRole("button", { name: "Generate project" }).click();
  await expect(page.locator("#diagnostics-region")).toContainText(/Generated \d+ files with \d+ committed Mobilis phases\. ZIP ready\./);
  await expect(page.locator("#workspace-files")).toContainText("generate/development-compose.yml");
  await page.getByRole("button", { name: "Stage all" }).click();
  await page.getByLabel("Git commit message").fill("Generate Redis and PostgreSQL infrastructure");
  await page.getByRole("button", { name: "Commit staged changes" }).click();
  await expect(page.locator("#workspace-summary")).toHaveText("Clean working tree");

  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Download workspace ZIP" }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe("mobilis-workspace.zip");

  const archive = new Blob([await readDownload(download)]);
  const reader = new ZipReader(new BlobReader(archive));
  const root = await mkdtemp(join(tmpdir(), "mobilis-workspace-e2e-"));
  try {
    const entries = await reader.getEntries();
    const names = new Set(entries.map(entry => entry.filename));
    expect(names.has(".git/HEAD")).toBe(true);
    expect(names.has("mobilis.rb")).toBe(true);
    expect(names.has("generate/development-compose.yml")).toBe(true);
    for (const entry of entries) {
      if (entry.directory) continue;
      expect(entry.filename.split("/")).not.toContain("..");
      const target = join(root, entry.filename);
      await mkdir(dirname(target), { recursive: true });
      await writeFile(target, Buffer.from(await entry.getData(new Uint8ArrayWriter())));
    }
    const git = (...args) => execFileSync("git", ["-C", root, ...args], { encoding: "utf8" }).trim();
    const messages = git("log", "--format=%s").split("\n");
    expect(messages).toEqual([
      "Generate Redis and PostgreSQL infrastructure",
      "Rename Redis service",
      "Initialize Mobilis project"
    ]);
    expect(git("status", "--porcelain")).toBe("");
    const committedFiles = git("ls-tree", "-r", "--name-only", "HEAD").split("\n");
    expect(committedFiles).toContain("mobilis.rb");
    expect(committedFiles).toContain("generate/development-compose.yml");
    expect(committedFiles).toContain("generate/compose/database.yml");
    expect(git("show", "HEAD:mobilis.rb")).toContain('redis("session-cache")');
    expect(git("show", "HEAD~1:mobilis.rb")).toContain('redis("session-cache")');
    expect(git("show", "HEAD~2:mobilis.rb")).toContain('redis("cache")');
  } finally {
    await reader.close();
    await rm(root, { recursive: true, force: true });
  }
});

test("generates Rails, Redis and PostgreSQL with real per-phase Git history in the downloaded project", async ({ page }) => {
  const bridgeErrors = [];
  page.on("pageerror", error => {
    if (/JS::Object#call|JS\.try_convert|not a JS::Object like object/.test(error.stack || error.message)) {
      bridgeErrors.push(error.stack || error.message);
    }
  });
  const source = [
    'require "mobilis"',
    '',
    'Mobilis::DSL.generate("rails-stack", starting_port: 11_000) do',
    '  rails("web", primary_database: postgres("database"), api: true)',
    '  redis("cache")',
    '  connect(from: "web", to: "cache")',
    'end',
    ''
  ].join("\n");
  const editor = page.getByLabel("Mobilis Ruby DSL");
  await editor.fill(source);
  await expect(page.locator("#diagnostics-region")).toContainText("Source is valid");
  await expect(page.locator("#architecture-canvas")).toContainText("Rails: web");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cache");
  await expect(page.locator("#architecture-canvas")).toContainText("PostgreSQL: database");

  await page.getByRole("button", { name: "Generate project" }).click();
  await expect(page.locator("#diagnostics-region")).toContainText(/Generated \d+ files with \d+ committed Mobilis phases\. ZIP ready\./);
  await expect(page.locator("#files-region")).toContainText("web/config/application.rb");
  await expect(page.locator("#files-region")).toContainText("web/Gemfile");
  await expect(page.locator("#files-region")).toContainText("compose/database.yml");

  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Download ZIP" }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe("mobilis-project.zip");

  const root = await mkdtemp(join(tmpdir(), "mobilis-rails-git-"));
  const zip = new ZipReader(new BlobReader(new Blob([await readDownload(download)])));
  try {
    const entries = await zip.getEntries();
    const names = new Set(entries.map(entry => entry.filename));
    for (const expected of [
      ".git/HEAD", "README.md", "web/Gemfile", "web/config/application.rb",
      "web/config/database.yml", "compose/database.yml",
      "compose/cache.yml", "compose/web.yml", "development-compose.yml"
    ]) expect(names.has(expected)).toBe(true);

    for (const entry of entries) {
      if (entry.directory) continue;
      expect(entry.filename.split("/")).not.toContain("..");
      const filename = join(root, entry.filename);
      await mkdir(dirname(filename), { recursive: true });
      await writeFile(filename, Buffer.from(await entry.getData(new Uint8ArrayWriter())));
    }
    const git = (...args) => execFileSync("git", ["-C", root, ...args], { encoding: "utf8" }).trim();
    const messages = git("log", "--format=%s").split("\n");
    expect(messages[0]).toMatch(/^\[mobilis\] /);
    expect(messages).toContain("[mobilis] Basic project files");
    expect(messages).toContain("[mobilis] add Rails project web");
    expect(messages).toContain("[mobilis] Compose overrides");
    expect(messages).toContain("[mobilis] Mobilis system config");
    expect(messages.length).toBeGreaterThan(5);
    expect(git("status", "--porcelain")).toBe("");
    expect(git("ls-tree", "-r", "--name-only", "HEAD").split("\n")).toContain("web/config/application.rb");
    const railsCommit = messages.indexOf("[mobilis] add Rails project web");
    const railsRevision = `HEAD~${railsCommit}`;
    expect(git("ls-tree", "-r", "--name-only", railsRevision)).toContain("web/config/application.rb");
    expect(git("ls-tree", "-r", "--name-only", "HEAD")).toContain("compose/database.yml");
    const earliest = `HEAD~${messages.length - 1}`;
    expect(git("ls-tree", "-r", "--name-only", earliest)).not.toContain("web/config/application.rb");
    expect(bridgeErrors, "Ruby/JS event bridge must not emit conversion errors after generation").toEqual([]);
  } finally {
    await zip.close();
    await rm(root, { recursive: true, force: true });
  }
});

test("isolates Mermaid failures from project generation", async ({ page }) => {
  await page.evaluate(() => window.MobilisDiagram.render("not a diagram", "{}"));
  await expect(page.locator(".diagram-render-error")).toContainText("Architecture rendering failed");

  await page.getByRole("button", { name: "Generate project" }).click();
  await expect(page.locator("#diagnostics-region")).toContainText(/Generated \d+ files with \d+ committed Mobilis phases\. ZIP ready\./);
});

async function readDownload(download) {
  const chunks = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function rubyInvocationCount(page) {
  return Number(await page.locator("#ruby-runtime-metrics").getAttribute("data-invocation-count"));
}

async function openEmbeddedMember(page, name) {
  const apiCard = page.locator(".service-card").filter({ has: page.locator('.service-name[value="api"]') });
  await apiCard.locator(".select-service").click();
  const archive = page.locator("details.embedded-archive:visible");
  await archive.evaluate(element => { element.open = true; });
  await page.getByRole("button", { name }).click();
}

test("downloads the exact DSL definition", async ({ page }) => {
  const editorSource = await page.getByLabel("Mobilis Ruby DSL").inputValue();
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Download DSL" }).click();
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toBe("mobilis.rb");
  expect(await download.createReadStream().then(async stream => {
    let content = "";
    for await (const chunk of stream) content += chunk.toString();
    return content;
  })).toBe(editorSource);
});

test("persists the authoritative DSL and generated files in the browser workspace", async ({ page }) => {
  await expect(page.locator("#workspace-summary")).toHaveText("Clean working tree");
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const changed = (await editor.inputValue()).replaceAll('"cache"', '"persistent-cache"');
  await editor.fill(changed);
  await expect(page.locator("#workspace-summary")).toContainText("changed file");

  await page.reload();
  await expect(page.getByRole("heading", { name: "Mobilis Browser Playground" })).toBeVisible({ timeout: 120_000 });
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(changed);
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: persistent-cache");

  await page.getByRole("button", { name: "Generate project" }).click();
  await expect(page.locator("#workspace-files")).toContainText("generate/development-compose.yml");
});

test("applies captured generator behavior through the persistent Ruby VM and workspace", async ({ page }) => {
  await page.evaluate(async () => {
    const encode = value => btoa(unescape(encodeURIComponent(value)));
    await window.MobilisWorkspace.persistGenerated(JSON.stringify({
      "rails-app/config/application.rb": encode("class Application; end\n"),
      "rails-app/config/environment.rb": encode("require_relative \"application\"\n")
    }));
  });

  const source = await page.getByLabel("Mobilis Ruby DSL").inputValue();
  const invocationCount = await rubyInvocationCount(page);
  await page.getByLabel("Compatibility application root").fill("generate/rails-app");
  await page.getByRole("button", { name: /Apply rspec:install 8\.1\.0 capture/ }).click();

  await expect(page.locator("#compatibility-status")).toContainText("3 created, 0 unchanged");
  await expect(page.locator("#workspace-files")).toContainText("generate/rails-app/.rspec");
  await page.locator("#workspace-files button", { hasText: "generate/rails-app/.rspec" }).click();
  await expect(page.locator("#workspace-diff")).toContainText("+--require spec_helper");
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(source);
  expect(await rubyInvocationCount(page)).toBe(invocationCount + 1);
  expect(await page.evaluate(() => window.MobilisRuntimeDiagnostics.vmInstances)).toBe(1);

  await page.getByRole("button", { name: /Apply rspec:install 8\.1\.0 capture/ }).click();
  await expect(page.locator("#compatibility-status")).toContainText("0 created, 3 unchanged");
  expect(await page.evaluate(() => window.MobilisRuntimeDiagnostics.vmInstances)).toBe(1);
});

test("persists invalid source while recovering the last valid projection after reload", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const original = await editor.inputValue();
  await editor.fill(original);
  await expect(page.locator("#workspace-summary")).toHaveText("Clean working tree");

  const invalid = "Mobilis::DSL.generate(";
  await editor.fill(invalid);
  await expect(page.locator("#workspace-summary")).toContainText("changed file");
  await page.reload();
  await expect(page.getByRole("heading", { name: "Mobilis Browser Playground" })).toBeVisible({ timeout: 120_000 });
  await expect(page.getByLabel("Mobilis Ruby DSL")).toHaveValue(invalid);
  await expect(page.locator("#architecture-region")).toContainText("Stale — source is invalid");
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cache");
});

test("stages, commits, diffs, protects dirty work, and restores a revision", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const initial = await editor.inputValue();
  await editor.fill(initial.replace('redis("cache")', 'redis("committed-cache")'));
  await expect(page.locator("#workspace-diff")).toContainText('+  redis("committed-cache")');

  await page.getByRole("button", { name: "Stage all" }).click();
  await page.getByLabel("Git commit message").fill("Rename cache service");
  await page.getByRole("button", { name: "Commit staged changes" }).click();
  await expect(page.locator("#workspace-summary")).toHaveText("Clean working tree");
  await expect(page.locator("#workspace-history")).toContainText("Rename cache service");

  await editor.fill((await editor.inputValue()).replace("committed-cache", "dirty-cache"));
  await page.locator("#workspace-history button", { hasText: "Restore" }).last().click();
  await expect(page.locator("#workspace-error")).toContainText("Commit or discard working-tree changes");
  await expect(editor).toHaveValue(/dirty-cache/);

  await page.getByRole("button", { name: "Stage all" }).click();
  await page.getByLabel("Git commit message").fill("Keep dirty cache rename");
  await page.getByRole("button", { name: "Commit staged changes" }).click();
  await page.locator("#workspace-history button", { hasText: "Restore" }).last().click();
  await expect(editor).toHaveValue(initial);
  await expect(page.locator("#architecture-canvas")).toContainText("Redis: cache");
  await expect(page.locator("#workspace-summary")).toContainText("changed file");
});
