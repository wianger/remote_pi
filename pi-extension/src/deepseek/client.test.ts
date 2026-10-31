import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, test } from "vitest";
import {
  DeepSeekClient,
  type DeepSeekServerRequest,
  type JsonObject,
} from "./client.js";

describe("DeepSeek ACP stdio client", () => {
  let root: string | undefined;
  let client: DeepSeekClient | undefined;

  afterEach(async () => {
    client?.close();
    // The Windows shim releases its working directory after the child exits.
    // Give process teardown a moment, then retry transient file locks.
    client = undefined;
    await new Promise((resolve) => setTimeout(resolve, 100));
    if (root) {
      rmSync(root, {
        recursive: true,
        force: true,
        maxRetries: 10,
        retryDelay: 100,
      });
      root = undefined;
    }
  });

  test.skipIf(process.platform !== "win32")(
    "uses JSON-RPC ACP, streams updates and answers permission requests",
    async () => {
      root = mkdtempSync(join(tmpdir(), "remote-pi-dsh-client-"));
      const script = join(root, "fake-dsh.mjs");
      const log = join(root, "requests.jsonl");
      const argsLog = join(root, "args.json");
      writeFileSync(script, `
import { appendFileSync, writeFileSync } from "node:fs";
const log = ${JSON.stringify(log)};
writeFileSync(${JSON.stringify(argsLog)}, JSON.stringify(process.argv.slice(2)));
let buffer = "";
let promptId;
const send = (value) => process.stdout.write(JSON.stringify(value) + "\\n");
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  for (;;) {
    const newline = buffer.indexOf("\\n");
    if (newline < 0) return;
    const line = buffer.slice(0, newline);
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    const message = JSON.parse(line);
    appendFileSync(log, JSON.stringify(message) + "\\n");
    if (message.method === "initialize") {
      send({ jsonrpc: "2.0", id: message.id, result: {
        protocolVersion: 1,
        agentCapabilities: { promptCapabilities: { image: true } },
      }});
    } else if (message.method === "session/new") {
      send({ jsonrpc: "2.0", id: message.id, result: {
        sessionId: "session-1",
        configOptions: [],
      }});
    } else if (message.method === "session/prompt") {
      promptId = message.id;
      send({ jsonrpc: "2.0", id: "permission-1",
        method: "session/request_permission",
        params: {
          sessionId: "session-1",
          toolCall: { toolCallId: "tool-1", title: "Run tests" },
          options: [{
            optionId: "allow-once", name: "Allow once", kind: "allow_once"
          }, {
            optionId: "reject-once", name: "Reject", kind: "reject_once"
          }]
        }
      });
    } else if (message.id === "permission-1") {
      send({ jsonrpc: "2.0", method: "session/update", params: {
        sessionId: "session-1",
        update: {
          sessionUpdate: "agent_message_chunk",
          messageId: "message-1",
          content: { type: "text", text: "done" }
        }
      }});
      send({ jsonrpc: "2.0", id: promptId, result: { stopReason: "end_turn" } });
    }
  }
});
setInterval(() => {}, 1000);
`);
      const shim = join(root, "dsh.cmd");
      writeFileSync(
        shim,
        `@ECHO off\r\n"%_prog%" "%dp0%\\fake-dsh.mjs" %*\r\n`,
      );
      client = new DeepSeekClient(root, shim);
      const started = await client.start();
      expect(started.supportsImages).toBe(true);
      expect(JSON.parse(readFileSync(argsLog, "utf8"))).toEqual([
        "--profile",
        "acp",
      ]);
      const created = await client.request("session/new", {
        cwd: root,
        mcpServers: [],
      }) as JsonObject;
      expect(created.sessionId).toBe("session-1");

      const permission = new Promise<DeepSeekServerRequest>((resolve) => {
        client!.once("request", resolve);
      });
      const updates: JsonObject[] = [];
      client.on("notification", (method, params) => {
        expect(method).toBe("session/update");
        updates.push(params);
      });
      const prompted = client.request("session/prompt", {
        sessionId: "session-1",
        prompt: [{ type: "text", text: "hello" }],
      }, 0);
      const request = await permission;
      client.respond(request.id, {
        outcome: { outcome: "selected", optionId: "allow-once" },
      });
      await expect(prompted).resolves.toEqual({ stopReason: "end_turn" });
      client.notify("session/cancel", { sessionId: "session-1" });
      await new Promise((resolve) => setTimeout(resolve, 20));
      expect(updates).toContainEqual(expect.objectContaining({
        sessionId: "session-1",
        update: expect.objectContaining({
          sessionUpdate: "agent_message_chunk",
        }),
      }));

      const requests = readFileSync(log, "utf8")
        .trim()
        .split("\n")
        .map((line) => JSON.parse(line) as JsonObject);
      expect(requests[0]).toMatchObject({
        jsonrpc: "2.0",
        method: "initialize",
        params: { protocolVersion: 1 },
      });
      expect(requests.at(-1)).toEqual({
        jsonrpc: "2.0",
        method: "session/cancel",
        params: { sessionId: "session-1" },
      });
    },
  );
});
