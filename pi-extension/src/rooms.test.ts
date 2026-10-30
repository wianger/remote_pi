import { SessionManager } from "@earendil-works/pi-coding-agent";
import { mkdtempSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "vitest";
import { roomIdForCwd, roomIdFor, roomIdForPiSession } from "./rooms.js";
import { defaultAgentName } from "./session/local_config.js";

describe("roomIdForCwd", () => {
  test("deterministic for the same cwd", () => {
    const a = roomIdForCwd("/tmp/some/path/that/may/not/exist");
    const b = roomIdForCwd("/tmp/some/path/that/may/not/exist");
    expect(a).toBe(b);
  });

  test("different cwds produce different ids", () => {
    const a = roomIdForCwd("/tmp/path/a");
    const b = roomIdForCwd("/tmp/path/b");
    expect(a).not.toBe(b);
  });

  test("id is 12-char base64url (safe in URLs / log lines)", () => {
    const id = roomIdForCwd("/tmp/path/c");
    expect(id).toMatch(/^[A-Za-z0-9_-]{12}$/);
  });

  test("realpath: symlinks resolve to the same id", () => {
    // Real fs setup: dir + symlink → dir. Both must produce identical ids.
    const tmp = mkdtempSync(join(tmpdir(), "remote-pi-rooms-"));
    const real = join(tmp, "real");
    mkdirSync(real);
    writeFileSync(join(real, "marker"), "x");
    const link = join(tmp, "link");
    symlinkSync(real, link);

    expect(roomIdForCwd(real)).toBe(roomIdForCwd(link));
  });

  test("non-existent cwd falls back to raw-path hash (no throw)", () => {
    const id = roomIdForCwd("/no/such/path/anywhere/xyz");
    expect(id).toMatch(/^[A-Za-z0-9_-]{12}$/);
  });
});

describe("roomIdFor (plan/41 — App↔Pi room per (cwd, name))", () => {
  const cwd = "/tmp/proj/backend";              // basename → default name "backend"
  const dflt = defaultAgentName(cwd);           // "backend"

  test("INVARIANT: default/absent name preserves the LEGACY cwd-only id (no re-keying)", () => {
    expect(roomIdFor(cwd)).toBe(roomIdForCwd(cwd));         // absent name
    expect(roomIdFor(cwd, dflt)).toBe(roomIdForCwd(cwd));   // name == defaultAgentName(cwd)
  });

  test("a custom agent_name produces a DISTINCT id (name-scoped)", () => {
    expect(roomIdFor(cwd, "reviewer")).not.toBe(roomIdForCwd(cwd));
    expect(roomIdFor(cwd, "reviewer")).toMatch(/^[A-Za-z0-9_-]{12}$/);
  });

  test("two different names in the SAME folder → distinct ids", () => {
    expect(roomIdFor(cwd, "alice")).not.toBe(roomIdFor(cwd, "bob"));
  });

  test("`folder` (default → legacy) vs `folder#2` (scoped) → distinct", () => {
    // The disambiguation for two UNNAMED agents: 1st keeps the legacy room,
    // 2nd gets a name-scoped room under the broker's #2 suffix.
    expect(roomIdFor(cwd, dflt)).toBe(roomIdForCwd(cwd));          // 1st = legacy
    expect(roomIdFor(cwd, `${dflt}#2`)).not.toBe(roomIdForCwd(cwd)); // 2nd = scoped
    expect(roomIdFor(cwd, dflt)).not.toBe(roomIdFor(cwd, `${dflt}#2`));
  });

  test("realpath: a symlinked cwd yields the SAME name-scoped id as the real dir", () => {
    const tmp = mkdtempSync(join(tmpdir(), "remote-pi-rooms41-"));
    const real = join(tmp, "real");
    mkdirSync(real);
    writeFileSync(join(real, "marker"), "x");
    const link = join(tmp, "link");
    symlinkSync(real, link);
    // Custom name (≠ either basename) → both take the scoped branch, which
    // canonicalizes via realpath → identical id despite different basenames.
    expect(roomIdFor(real, "reviewer")).toBe(roomIdFor(link, "reviewer"));
  });

  test("scoped id is 12-char base64url", () => {
    expect(roomIdFor(cwd, "reviewer")).toMatch(/^[A-Za-z0-9_-]{12}$/);
  });
});

describe("persisted Pi conversation identity", () => {
  test("daemon and resume share identity but keep separate command destinations", () => {
    const daemon = roomIdForPiSession("/tmp/project", "project", "same-session", true);
    const terminal = roomIdForPiSession("/tmp/project", "project#2", "same-session");
    const pattern = /^pi_([A-Za-z0-9_-]{16})_([di])_([A-Za-z0-9_-]{12})$/;
    expect(daemon.match(pattern)?.[1]).toBe(terminal.match(pattern)?.[1]);
    expect(daemon).not.toBe(terminal);
    expect(daemon.match(pattern)?.[2]).toBe("d");
    expect(terminal.match(pattern)?.[2]).toBe("i");
  });
  test("two actual conversations in the same directory stay independent", () => {
    const a = roomIdForPiSession("/tmp/project", "project", "conversation-A");
    const b = roomIdForPiSession("/tmp/project", "project", "conversation-B");
    expect(a.slice(0, 19)).not.toBe(b.slice(0, 19));
  });
  test("missing SDK session identity preserves the old room id", () => {
    expect(roomIdForPiSession("/tmp/project", "project", undefined)).toBe(roomIdFor("/tmp/project", "project"));
  });
});


test("SDK create and desktop resume expose the same persisted conversation id", () => {
  const dir = mkdtempSync(join(tmpdir(), "remote-pi-resume-"));
  try {
    const mobile = SessionManager.create(dir, dir);
    mobile.appendMessage({ role: "assistant", content: [{ type: "text", text: "Saved conversation" }],
      api: "openai-responses", provider: "openai", model: "test", stopReason: "stop", timestamp: Date.now(),
      usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0,
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } });
    const resumed = SessionManager.open(mobile.getSessionFile()!);
    expect(resumed.getSessionId()).toBe(mobile.getSessionId());
    const daemon = roomIdForPiSession(dir, "project", mobile.getSessionId(), true);
    const terminal = roomIdForPiSession(dir, "project#2", resumed.getSessionId());
    expect(daemon.slice(0, 19)).toBe(terminal.slice(0, 19));
    expect(daemon).not.toBe(terminal);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
