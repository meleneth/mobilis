// Generic Git machinery. The caller owns repository boundaries, commit
// messages and phase timing; this adapter only applies byte-level changes.
export function createGitCapability({ fs, pfs, git, author }) {
  function checkPath(name) {
    if (typeof name !== "string" || !name ||
        name.startsWith("/") ||
        name.split("/").some(part => !part || part === "." || part === ".." || part === ".git")) {
      throw new Error(`Unsafe Git path: ${name}`);
    }
  }

  async function ensureParent(path) {
    const parent = path.slice(0, path.lastIndexOf("/")) || "/";
    if (parent === "/") return;
    try {
      await pfs.mkdir(parent);
    } catch (error) {
      if (error.code === "EEXIST") return;
      if (error.code !== "ENOENT") throw error;
      await ensureParent(parent);
      await pfs.mkdir(parent);
    }
  }

  async function changed(existingPath, bytes) {
    try {
      const previous = new Uint8Array(await pfs.readFile(existingPath));
      return previous.length !== bytes.length ||
        previous.some((value, index) => value !== bytes[index]);
    } catch (error) {
      if (error.code === "ENOENT") return true;
      throw error;
    }
  }

  return {
    async initialize(root, branch = "main") {
      await git.init({ fs, dir: root, defaultBranch: branch });
    },

    async checkpoint(root, { message, writes = {}, deletes = [] }) {
      if (typeof message !== "string" || !message.trim()) {
        throw new Error("A Git checkpoint requires a commit message");
      }
      let staged = 0;
      const names = Object.keys(writes);
      const removed = new Set(deletes);
      for (const name of [...names, ...removed]) checkPath(name);
      if (names.some(name => removed.has(name))) {
        throw new Error("Git checkpoint writes and deletes the same path");
      }
      for (const name of removed) {
        const path = `${root}/${name}`;
        try {
          await pfs.unlink(path);
        } catch (error) {
          if (error.code !== "ENOENT") throw error;
        }
        await git.remove({ fs, dir: root, filepath: name });
        staged += 1;
      }
      for (const name of names.sort()) {
        const path = `${root}/${name}`;
        const bytes = writes[name];
        if (!(bytes instanceof Uint8Array)) throw new Error(`Git write is not binary: ${name}`);
        if (await changed(path, bytes)) {
          await ensureParent(path);
          await pfs.writeFile(path, bytes);
          if (!(await git.isIgnored({ fs, dir: root, filepath: name }))) {
            await git.add({ fs, dir: root, filepath: name });
            staged += 1;
          }
        }
      }
      if (!staged) throw new Error(`Generator emitted no trackable changes: ${message}`);
      let unborn = false;
      try {
        await git.resolveRef({ fs, dir: root, ref: "HEAD" });
      } catch (error) {
        unborn = (error?.code === "NotFoundError" || error?.name === "NotFoundError") &&
          String(error.message).includes("refs/heads/");
        if (!unborn) throw error;
      }
      if (!unborn) {
        const matrix = await git.statusMatrix({ fs, dir: root });
        if (!matrix.some(([, head, , stage]) => head !== stage)) {
          throw new Error(`Generator emitted an empty Git checkpoint: ${message}`);
        }
      }
      return git.commit({ fs, dir: root, message, author });
    },

    log(root) {
      return git.log({ fs, dir: root });
    }
  };
}
