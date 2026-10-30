import { expect, test } from "vitest";
import { workspaceAgents, workspaceAgentDefinition } from "./agents.js";
import { availableAgents } from "./directories.js";
import { openWorkspace } from "./service.js";

test("catalog reports availability and the reason for an unavailable adapter", async () => {
  const catalog = await availableAgents(async (command) => command === "pi" ? "/bin/pi" : null);
  expect(new Set(workspaceAgents.map((agent) => agent.id)).size).toBe(workspaceAgents.length);
  expect(catalog).toContainEqual(expect.objectContaining({ id: "pi", available: true }));
  expect(catalog).toContainEqual(expect.objectContaining({ id: "codex", available: false, reason: expect.stringContaining("not installed") }));
  expect(catalog.every((agent) => agent.description)).toBe(true);
});

test("unknown ids are rejected before starting a session", async () => {
  expect(workspaceAgentDefinition("unregistered-agent")).toBeUndefined();
  await expect(openWorkspace("/unused", "unregistered-agent")).rejects.toThrow(/supported/);
});
