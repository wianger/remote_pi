import { createInterface } from "node:readline";
import { defaultAgentName, loadLocalConfig } from "../session/local_config.js";
import { acquireCwdLock } from "../session/cwd_lock.js";
import { roomIdFor } from "../rooms.js";
import { OwnerRelayHost } from "../transport/owner_host.js";
import { handleWorkspaceRequest } from "../workspace/service.js";
import { object } from "./client.js";
import { DeepSeekSession } from "./session.js";

export async function runDeepSeekHost(): Promise<void> {
  const cwd = process.cwd();
  const config = loadLocalConfig(cwd);
  const name = config.agent_name || `DeepSeek · ${defaultAgentName(cwd)}`;
  const roomId = roomIdFor(cwd, name);
  const lock = await acquireCwdLock(cwd, name);
  if (!lock.ok) throw new Error("This DeepSeek session is already open.");
  let stopping = false;
  let session: DeepSeekSession | null = null;
  const host = new OwnerRelayHost({
    roomId,
    roomMeta: { name, cwd },
    onMessage: (sender, message) => {
      if (message.type === "workspace_browse" || message.type === "workspace_open") {
        void handleWorkspaceRequest(sender, message);
      } else {
        void session?.handle(sender, message);
      }
    },
  });
  const shutdown = (code = 0): void => {
    if (stopping) return;
    stopping = true;
    host.stop();
    session?.close();
    lock.release();
    process.exit(code);
  };
  process.on("SIGINT", () => shutdown());
  process.on("SIGTERM", () => shutdown());
  try {
    session = new DeepSeekSession({
      cwd,
      broadcast: (message) => host.broadcast(message),
      onModel: (model) => host.updateMeta({ model }),
      onBusy: (busy) => {
        host.updateMeta({ working: busy });
        process.stdout.write(
          JSON.stringify({ type: busy ? "message_start" : "message_end" }) + "\n",
        );
      },
      onClosed: (error) => {
        process.stderr.write(`[remote-pi] ${error.message}\n`);
        shutdown(1);
      },
    });
    await session.start();
    await host.start();
    process.stdout.write(
      JSON.stringify({ type: "remote_pi_ready", room_id: roomId }) + "\n",
    );
    const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
    input.on("line", (line) => {
      let request: Record<string, unknown>;
      try {
        request = object(JSON.parse(line));
      } catch {
        return;
      }
      if (request.type === "get_state") {
        process.stdout.write(JSON.stringify({
          type: "response",
          command: "get_state",
          id: request.id,
          success: true,
          data: { isStreaming: session?.isBusy ?? false },
        }) + "\n");
      } else if (request.type === "prompt" && typeof request.message === "string") {
        void session?.sendPrompt(request.message).then(() => {
          process.stdout.write(JSON.stringify({
            type: "response",
            command: "prompt",
            id: request.id,
            success: true,
          }) + "\n");
        }).catch((error: unknown) => {
          process.stdout.write(JSON.stringify({
            type: "response",
            command: "prompt",
            id: request.id,
            success: false,
            error: error instanceof Error
              ? error.message
              : "DeepSeek prompt failed.",
          }) + "\n");
        });
      }
    });
    input.on("close", () => shutdown());
  } catch (error) {
    host.stop();
    session?.close();
    lock.release();
    throw error;
  }
}
