import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  page.on("console", message => console.log(`[browser:${message.type()}] ${message.text()}`));
  page.on("pageerror", error => console.error(`[browser:error] ${error.stack || error}`));
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Mobilis Browser Playground" })).toBeVisible({ timeout: 120_000 });
});

test("synchronizes visual and Ruby editing, including Rails authoring", async ({ page }) => {
  await page.getByLabel("New service name").fill("web");
  await page.locator("#new-service-type").selectOption("rails");
  await page.getByRole("button", { name: "Add service" }).click();

  const editor = page.getByLabel("Mobilis Ruby DSL");
  await expect(editor).toHaveValue(/rails\("web"\)/);
  const railsCard = page.locator(".service-card").filter({ has: page.locator('.service-name[value="web"]') });
  await expect(railsCard).toContainText("Local generation");

  await editor.fill((await editor.inputValue()).replaceAll('"cache"', '"session-cache"'));
  await expect(page.locator(".service-name").nth(1)).toHaveValue("session-cache");
});

test("preserves the last visual model while invalid Ruby is repaired", async ({ page }) => {
  const editor = page.getByLabel("Mobilis Ruby DSL");
  const valid = await editor.inputValue();
  const cardCount = await page.locator(".service-card").count();

  await editor.fill("Mobilis::DSL.generate(");
  await expect(page.locator("#diagnostics-region")).toContainText("Source or generation error");
  await expect(page.locator(".service-card")).toHaveCount(cardCount);

  await editor.fill(valid);
  await expect(page.locator("#diagnostics-region")).toContainText("Source is valid");
});

test("generates real files and navigates the read-only browser", async ({ page }) => {
  await page.getByRole("button", { name: "Generate project" }).click();
  await expect(page.locator("#diagnostics-region")).toContainText(/Generated \d+ files locally with Mobilis/);

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

async function readDownload(download) {
  const chunks = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk);
  return Buffer.concat(chunks);
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
