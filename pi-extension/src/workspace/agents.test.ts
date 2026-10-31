import { expect, test } from "vitest";
import { workspaceAgents, workspaceAgentDefinition } from "./agents.js";
import { availableAgents } from "./directories.js";
import { openWorkspace } from "./service.js";

test("catalog reports availability and the reason for an unavailable adapter", async () => {
  const catalog = await availableAgents(
    async (command) => command === "pi" ? "/bin/pi" : null,
    async () => false,
  );
  expect(new Set(workspaceAgents.map((agent) => agent.id)).size).toBe(workspaceAgents.length);
  expect(catalog).toContainEqual(expect.objectContaining({ id: "pi", available: true }));
  expect(catalog).toContainEqual(expect.objectContaining({ id: "codex", available: false, reason: expect.stringContaining("not installed") }));
  expect(catalog).toContainEqual(expect.objectContaining({ id: "deepseek", available: false, reason: expect.stringContaining("not installed") }));
  expect(catalog.every((agent) => agent.description)).toBe(true);
});

test("catalog discovers DeepSeek Harness through the dsh executable", async () => {
  const catalog = await availableAgents(
    async (command) => command === "dsh" ? "/bin/dsh" : null,
    async () => false,
  );
  expect(catalog).toContainEqual(
    expect.objectContaining({
      id: "deepseek",
      name: "DeepSeek",
      available: true,
    }),
  );
});

test("catalog finds DeepSeek Harness inside the desktop bundle", async () => {
  // The official desktop app never puts `dsh` on PATH; the catalog probe must
  // still report DeepSeek as available when the bundled CLI exists.
  const catalog = await availableAgents(
    async () => null,
    async () => true,
  );
  expect(catalog).toContainEqual(
    expect.objectContaining({ id: "deepseek", available: true }),
  );
});

test("DeepSeek catalog honors a custom harness executable", async () => {
  const previous = process.env["REMOTE_PI_DSH_BIN"];
  process.env["REMOTE_PI_DSH_BIN"] = "C:\\tools\\custom-dsh.exe";
  try {
    const commands: string[] = [];
    const catalog = await availableAgents(async (command) => {
      commands.push(command);
      return command === "C:\\tools\\custom-dsh.exe"
        ? "C:\\tools\\custom-dsh.exe"
        : null;
    }, async () => false);
    expect(commands).toContain("C:\\tools\\custom-dsh.exe");
    expect(catalog).toContainEqual(
      expect.objectContaining({ id: "deepseek", available: true }),
    );
  } finally {
    if (previous === undefined) delete process.env["REMOTE_PI_DSH_BIN"];
    else process.env["REMOTE_PI_DSH_BIN"] = previous;
  }
});

test("unknown ids are rejected before starting a session", async () => {
  expect(workspaceAgentDefinition("unregistered-agent")).toBeUndefined();
  await expect(openWorkspace("/unused", "unregistered-agent")).rejects.toThrow(/supported/);
});
