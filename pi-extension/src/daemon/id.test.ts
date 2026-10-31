import { describe, expect, test } from "vitest";
import { mkdirSync, mkdtempSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { daemonIdForAgent, daemonIdForCwd } from "./id.js";

describe("daemonIdForCwd", () => {
  test("deterministic for the same cwd", () => {
    const a = daemonIdForCwd("/tmp/some/path/that/may/not/exist");
    const b = daemonIdForCwd("/tmp/some/path/that/may/not/exist");
    expect(a).toBe(b);
  });

  test("different cwds produce different ids", () => {
    const a = daemonIdForCwd("/tmp/path/a");
    const b = daemonIdForCwd("/tmp/path/b");
    expect(a).not.toBe(b);
  });

  test("id is 8-char hex (lowercase a-f + digits)", () => {
    const id = daemonIdForCwd("/tmp/path/c");
    expect(id).toMatch(/^[0-9a-f]{8}$/);
  });

  test("realpath: symlinks collapse to the same id", () => {
    const tmp = mkdtempSync(join(tmpdir(), "pi-daemonid-"));
    const real = join(tmp, "real");
    mkdirSync(real);
    const link = join(tmp, "link");
    symlinkSync(real, link);
    expect(daemonIdForCwd(real)).toBe(daemonIdForCwd(link));
  });

  test("non-existent cwd falls back to raw-path hash (no throw)", () => {
    const id = daemonIdForCwd("/no/such/path/anywhere/xyz");
    expect(id).toMatch(/^[0-9a-f]{8}$/);
  });
});

test("Pi, Codex and DeepSeek coexist in the same folder without changing Pi ids", () => {
  const cwd = "/tmp/shared-folder";
  const pi = daemonIdForAgent(cwd, "pi");
  const codex = daemonIdForAgent(cwd, "codex");
  const deepseek = daemonIdForAgent(cwd, "deepseek");
  expect(pi).toBe(daemonIdForCwd(cwd));
  expect(new Set([pi, codex, deepseek]).size).toBe(3);
});
