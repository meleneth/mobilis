import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import git from "isomorphic-git";
import { createGitCapability } from "../public/git-capability.js";

const author = { name: "Mobilis Test", email: "test@mobilis.local" };
const encode = value => new TextEncoder().encode(value);
const decode = value => new TextDecoder().decode(value);

test("a caller owns the generated repository and every authentic commit boundary", async () => {
  const root = await mkdtemp(join(tmpdir(), "mobilis-git-capability-"));
  const pfs = fs.promises;
  const capability = createGitCapability({ fs, pfs, git, author });
  try {
    await capability.initialize(root);

  await capability.checkpoint(root, {
    message: "[mobilis] Basic project files",
    writes: {
      "README.md": encode("# Mobilis\n"),
      ".gitignore": encode("data\n")
    }
  });
  await capability.checkpoint(root, {
    message: "[mobilis] add Rails project web",
    writes: {
      "web/Gemfile": encode('source "https://rubygems.org"\ngem "rails"\n'),
      "web/config/application.rb": encode("module Web; end\n")
    }
  });
  await capability.checkpoint(root, {
    message: "[mobilis] Compose overrides",
    writes: {
      "development-compose.yml": encode("include: []\n")
    }
  });

  const log = await capability.log(root);
  assert.deepEqual(log.map(entry => entry.commit.message.trimEnd()), [
    "[mobilis] Compose overrides",
    "[mobilis] add Rails project web",
    "[mobilis] Basic project files"
  ]);
  assert.notEqual(log[0].oid, log[1].oid);
  const current = await git.readBlob({ fs, dir: root, oid: log[0].oid, filepath: "web/config/application.rb" });
  assert.equal(decode(current.blob), "module Web; end\n");
  const initial = await git.listFiles({ fs, dir: root, ref: log[2].oid });
  assert.deepEqual(initial.sort(), [".gitignore", "README.md"]);
  const previous = await git.listFiles({ fs, dir: root, ref: log[1].oid });
  assert.ok(previous.includes("web/config/application.rb"));
  assert.ok(!previous.includes("development-compose.yml"));
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
