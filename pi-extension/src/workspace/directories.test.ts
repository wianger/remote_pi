import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { browseDirectory, resolveDirectory } from "./directories.js";

describe("mobile folder browsing", () => {
  let root: string;
  beforeEach(() => { root = mkdtempSync(join(tmpdir(), "remote-pi-workspace-test-")); });
  afterEach(() => {
    if (dirname(root) !== realpathSync(tmpdir()) || !basename(root).startsWith("remote-pi-workspace-test-")) {
      throw new Error("Refusing to remove a non-test directory.");
    }
    rmSync(root, { recursive: true, force: true });
  });

  test("lists only folders and never includes a file's contents", async () => {
    mkdirSync(join(root, "项目"));
    mkdirSync(join(root, "folder with spaces"));
    mkdirSync(join(root, ".hidden"));
    writeFileSync(join(root, "private.txt"), "PRIVATE TEST CONTENT");
    const listing = await browseDirectory(root);
    expect(listing.directories.map((entry) => entry.name).sort()).toEqual(["folder with spaces", "项目"]);
    expect(JSON.stringify(listing)).not.toContain("PRIVATE TEST CONTENT");
    expect(listing.path).toBe(realpathSync(root));
    expect(listing.parent).toBe(dirname(realpathSync(root)));
    expect(listing.agents.map((agent) => agent.id)).toEqual(["pi", "codex"]);
  });

  test("hidden folders are opt-in", async () => {
    mkdirSync(join(root, ".project"));
    expect((await browseDirectory(root)).directories).toHaveLength(0);
    expect((await browseDirectory(root, true)).directories[0]?.name).toBe(".project");
  });

  test("rejects missing paths, files, relative paths and null bytes", async () => {
    writeFileSync(join(root, "file"), "test");
    await expect(resolveDirectory(join(root, "missing"))).rejects.toThrow();
    await expect(resolveDirectory(join(root, "file"))).rejects.toThrow(/folder/);
    await expect(resolveDirectory("relative/project")).rejects.toThrow(/absolute/);
    await expect(resolveDirectory(root + "\0suffix")).rejects.toThrow(/Invalid/);
  });
});
