import test from "node:test";
import assert from "node:assert/strict";
import LightningFS from "@isomorphic-git/lightning-fs";
import git from "isomorphic-git";
import { createGitCapability } from "../public/git-capability.js";

const author = { name: "Mobilis Test", email: "test@mobilis.local" };
const encode = value => new TextEncoder().encode(value);
const decode = value => new TextDecoder().decode(value);

test("a caller owns the generated repository and every authentic commit boundary", async () => {
  const fs = new LightningFS("mobilis-git-capability-test", { db: new LightningFS.MemoryBackend() });
  const pfs = fs.promises;
  await pfs.mkdir("/generated");
  const capability = createGitCapability({ fs, pfs, git, author });
  await capability.initialize("/generated");

  await capability.checkpoint("/generated", {
    message: "[mobilis] Basic project files",
    writes: {
      "README.md": encode("# Mobilis\n"),
      ".gitignore": encode("data\n")
    }
  });
  await capability.checkpoint("/generated", {
    message: "[mobilis] add Rails project web",
    writes: {
      "web/Gemfile": encode('source "https://rubygems.org"\ngem "rails"\n'),
      "web/config/application.rb": encode("module Web; end\n")
    }
  });
  await capability.checkpoint("/generated", {
    message: "[mobilis] Compose overrides",
    writes: {
      "development-compose.yml": encode("include: []\n")
    }
  });

  const log = await capability.log("/generated");
  assert.deepEqual(log.map(entry => entry.commit.message.trimEnd()), [
    "[mobilis] Compose overrides",
    "[mobilis] add Rails project web",
    "[mobilis] Basic project files"
  ]);
  assert.notEqual(log[0].oid, log[1].oid);
  const current = await git.readBlob({ fs, dir: "/generated", oid: log[0].oid, filepath: "web/config/application.rb" });
  assert.equal(decode(current.blob), "module Web; end\n");
  const initial = await git.listFiles({ fs, dir: "/generated", ref: log[2].oid });
  assert.deepEqual(initial.sort(), [".gitignore", "README.md"]);
  const previous = await git.listFiles({ fs, dir: "/generated", ref: log[1].oid });
  assert.ok(previous.includes("web/config/application.rb"));
  assert.ok(!previous.includes("development-compose.yml"));
});
