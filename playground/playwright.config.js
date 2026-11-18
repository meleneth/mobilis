import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./test/browser",
  timeout: 120_000,
  expect: { timeout: 30_000 },
  use: {
    baseURL: "http://127.0.0.1:4173",
    browserName: "chromium",
    launchOptions: { executablePath: "/usr/bin/google-chrome" },
    acceptDownloads: true
  },
  webServer: {
    command: "ruby -run -e httpd public -p 4173",
    port: 4173,
    reuseExistingServer: true,
    timeout: 30_000
  }
});
