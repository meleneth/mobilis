#!/usr/bin/env node

import { chromium } from "@playwright/test";

const [url, label = "playground"] = process.argv.slice(2);
if (!url) {
  console.error("usage: measure_browser.mjs URL [LABEL]");
  process.exit(64);
}

const browser = await chromium.launch({ executablePath: "/usr/bin/google-chrome" });
try {
  const context = await browser.newContext();
  const page = await context.newPage();
  const cold = await initialize(page, url);
  const warm = await initialize(page, url);

  await page.getByLabel("New service name").fill("benchmark-cache");
  await page.locator("#new-service-type").selectOption("redis");
  const editStarted = performance.now();
  await page.getByRole("button", { name: "Add service" }).click();
  await page.locator(".service-name").nth(2).waitFor();
  const visualEditMs = performance.now() - editStarted;

  const source = page.getByLabel("Mobilis Ruby DSL");
  const invocationBeforeValidation = await invocationCount(page);
  const validationStarted = performance.now();
  await source.fill(`# benchmark validation\n${await source.inputValue()}`);
  await page.waitForFunction(previous => {
    const metrics = document.getElementById("ruby-runtime-metrics");
    return metrics && Number(metrics.dataset.invocationCount) > previous;
  }, invocationBeforeValidation);
  await page.locator("#diagnostics-region").getByText("Source is valid", { exact: false }).waitFor();
  const validationMs = performance.now() - validationStarted;

  const browserDiagnostics = await page.evaluate(() => ({
    runtime: window.MobilisRuntimeDiagnostics || null,
    usedJsHeapBytes: performance.memory?.usedJSHeapSize ?? null
  }));
  console.log(JSON.stringify({label, cold, warm, visualEditMs, validationMs, ...browserDiagnostics}, null, 2));
  await context.close();
} finally {
  await browser.close();
}

async function initialize(page, target) {
  const started = performance.now();
  await page.goto(target);
  await page.getByRole("heading", { name: "Mobilis Browser Playground" }).waitFor({ timeout: 120_000 });
  const usableMs = performance.now() - started;
  const resources = await page.evaluate(() => performance.getEntriesByType("resource")
    .filter(entry => /(?:mobilis\.wasm|filesystem\.json|ruby\+stdlib\.wasm|mobilis-app-.*\.tar)$/.test(new URL(entry.name).pathname))
    .map(entry => ({name: new URL(entry.name).pathname, transferSize: entry.transferSize, decodedBodySize: entry.decodedBodySize})));
  return {usableMs, resources};
}

async function invocationCount(page) {
  return Number(await page.locator("#ruby-runtime-metrics").getAttribute("data-invocation-count"));
}
