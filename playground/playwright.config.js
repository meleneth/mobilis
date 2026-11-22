import { defineConfig } from "@playwright/test";

const externalUrl = process.env.PLAYWRIGHT_BASE_URL;

export default defineConfig({
  testDir: "./test/browser",
  timeout: 120_000,
  expect: { timeout: 30_000 },
  use: {
    baseURL: externalUrl || "http://127.0.0.1:4173",
    browserName: "chromium",
    launchOptions: { executablePath: "/usr/bin/google-chrome" },
    acceptDownloads: true
  },
  webServer: externalUrl ? undefined : {
    command: "ruby -run -e httpd public -p 4173",
    port: 4173,
    reuseExistingServer: true,
    timeout: 30_000
  }
});
