import { spawn } from "node:child_process";
import { closeSync, existsSync, mkdirSync, openSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { callSupervisor, supervisorOnline } from "../daemon/client.js";
import type { PeerChannel } from "../transport/peer_channel.js";
import { roomIdFor } from "../rooms.js";
import { availableAgents, browseDirectory, resolveDirectory } from "./directories.js";
import type { OpenedWorkspace, WorkspaceRequest } from "./types.js";
import { workspaceAgentDefinition } from "./agents.js";

let supervisorStartup: Promise<void> | null = null;

/** Start the per-user manager on demand, without installing a login service. */
export async function ensureWorkspaceSupervisor(): Promise<void> {
  if (await supervisorOnline()) return;
  if (supervisorStartup) return supervisorStartup;
  supervisorStartup = (async () => {
    const entrypoint = fileURLToPath(new URL("../bin/supervisord.js", import.meta.url));
    if (!existsSync(entrypoint)) throw new Error("Computer support files are missing. Rebuild Remote Pi first.");
    const root = join(process.env.REMOTE_PI_HOME || homedir(), ".pi", "remote");
    mkdirSync(root, { recursive: true, mode: 0o700 });
    const log = openSync(join(root, "supervisord.log"), "a", 0o600);
    let launchError: Error | null = null;
    try {
      const child = spawn(process.execPath, [entrypoint, "--on-demand"], {
        detached: true,
        windowsHide: true,
        stdio: ["ignore", log, log],
        env: { ...process.env },
      });
      child.once("error", (error) => { launchError = error; });
      child.unref();
    } finally {
      closeSync(log);
    }
    for (let attempt = 0; attempt < 25; attempt++) {
      if (launchError) throw launchError;
      if (await supervisorOnline()) return;
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    throw new Error("Could not start the computer's session manager.");
  })();
  try { await supervisorStartup; }
  finally { supervisorStartup = null; }
}

export async function openWorkspace(path: string, agent: unknown): Promise<OpenedWorkspace> {
  const definition = workspaceAgentDefinition(agent);
  if (!definition) throw new Error("Choose an agent supported by this computer.");
  if (typeof path !== "string" || !path.trim()) throw new Error("Choose a folder first.");
  const cwd = await resolveDirectory(path);
  const agents = await availableAgents();
  if (!agents.find((entry) => entry.id === definition.id)?.available) {
    throw new Error(`${definition.name} is not installed on this computer.`);
  }
  await ensureWorkspaceSupervisor();
  const result = await callSupervisor({ op: "open_workspace", cwd, agent: definition.id });
  return { ...result, agent: definition.id, room_id: roomIdFor(result.cwd, result.name) };
}

/** Called only after the transport has authenticated a paired mobile owner. */
export async function handleWorkspaceRequest(sender: PeerChannel, message: WorkspaceRequest): Promise<void> {
  if (typeof message.id !== "string" || message.id.length === 0 || message.id.length > 200) return;
  try {
    if (message.type === "workspace_browse") {
      const directory = await browseDirectory(message.path, message.show_hidden === true);
      sender.send({ type: "workspace_listing", in_reply_to: message.id, directory });
    } else {
      const workspace = await openWorkspace(message.path, message.agent);
      sender.send({ type: "workspace_opened", in_reply_to: message.id, workspace });
    }
  } catch (error) {
    const detail = error instanceof Error ? error.message : "Could not open this folder.";
    sender.send({ type: "workspace_error", in_reply_to: message.id, error: detail });
  }
}
