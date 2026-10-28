import { EventEmitter } from "node:events";
import { mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import type { PeerChannel } from "../transport/peer_channel.js";
import type { ServerMessage, SessionHistoryEvent } from "../protocol/types.js";
import { CodexSession } from "./session.js";
import type { CodexClientEvents, JsonObject } from "./client.js";

class FakeCodex extends EventEmitter<CodexClientEvents> {
  start = vi.fn(async () => {});
  respond = vi.fn();
  rejectRequest = vi.fn();
  close = vi.fn();
  request = vi.fn(async (method: string, _params: JsonObject = {}): Promise<unknown> => {
    if (method === "thread/start" || method === "thread/resume") return { thread: { id: "thread-1" }, model: "configured-model" };
    if (method === "turn/start") return { turn: { id: "turn-1" } };
    if (method === "model/list") return { data: [{ id: "id", model: "configured-model", displayName: "Configured model",
      supportedReasoningEfforts: [{ reasoningEffort: "high" }], inputModalities: ["text", "image"] }] };
    return {};
  });
}

describe("Codex mobile session bridge", () => {
  let root: string;
  let client: FakeCodex;
  let broadcasts: ServerMessage[];
  let replies: ServerMessage[];
  let sender: PeerChannel;
  let session: CodexSession;
  beforeEach(() => {
    root = mkdtempSync(join(tmpdir(), "remote-pi-codex-test-"));
    client = new FakeCodex();
    broadcasts = [];
    replies = [];
    sender = { send: (message) => replies.push(message) };
    session = new CodexSession({ cwd: root, client, statePath: join(root, "state.json"), broadcast: (message) => broadcasts.push(message) });
  });
  afterEach(() => {
    session.close();
    if (dirname(root) !== realpathSync(tmpdir()) || !basename(root).startsWith("remote-pi-codex-test-")) throw new Error("Unsafe test cleanup path.");
    rmSync(root, { recursive: true, force: true });
  });

  test("uses the selected folder and preserves configured sandbox/approval policy", async () => {
    await session.start();
    const params = client.request.mock.calls.find(([method]) => method === "thread/start")?.[1];
    expect(params?.cwd).toBe(root);
    expect(params).not.toHaveProperty("approvalPolicy");
    expect(params).not.toHaveProperty("sandbox");
  });

  test("echoes accepted input, streams Chinese text, and synchronizes the completed response", async () => {
    await session.start();
    await session.handle(sender, { type: "user_message", id: "phone-message", text: "你好" });
    client.emit("notification", "item/agentMessage/delta", { threadId: "thread-1", itemId: "answer-1", delta: "你好，" });
    client.emit("notification", "item/agentMessage/delta", { threadId: "thread-1", itemId: "answer-1", delta: "世界" });
    expect(session.isBusy).toBe(true);
    client.emit("notification", "turn/completed", { threadId: "thread-1", turn: { id: "turn-1", status: "completed" } });
    expect(session.isBusy).toBe(false);
    expect(broadcasts.some((message) => message.type === "user_message" && message.id === "phone-message")).toBe(true);
    await session.handle(sender, { type: "session_sync", id: "sync", limit: 1 });
    const history = replies.find((message) => message.type === "session_history");
    expect(history?.type === "session_history" && history.events).toEqual(expect.arrayContaining([
      expect.objectContaining({ type: "user_input", id: "phone-message", text: "你好" }),
      expect.objectContaining({ type: "agent_message", in_reply_to: "phone-message", text: "你好，世界" }),
    ]));
  });

  test("never auto-approves commands; an explicit approval applies only once", async () => {
    await session.start();
    client.emit("request", { id: 7, method: "item/commandExecution/requestApproval",
      params: { threadId: "thread-1", itemId: "command-1", command: "git status", cwd: root } });
    expect(client.respond).not.toHaveBeenCalled();
    expect(broadcasts).toContainEqual(expect.objectContaining({ type: "tool_request", args: expect.objectContaining({ approval_required: true }) }));
    await session.handle(sender, { type: "approve_tool", id: "approval", tool_call_id: "command-1", decision: "allow" });
    expect(client.respond).toHaveBeenCalledExactlyOnceWith(7, { decision: "accept" });
    await session.handle(sender, { type: "approve_tool", id: "duplicate", tool_call_id: "command-1", decision: "allow" });
    expect(client.respond).toHaveBeenCalledTimes(1);
  });

  test("denial is sent to Codex, and permission grants are scoped to the current turn", async () => {
    await session.start();
    client.emit("request", { id: 8, method: "item/fileChange/requestApproval", params: { threadId: "thread-1", itemId: "patch" } });
    await session.handle(sender, { type: "approve_tool", id: "deny", tool_call_id: "patch", decision: "deny" });
    expect(client.respond).toHaveBeenCalledWith(8, { decision: "decline" });
    client.emit("request", { id: 9, method: "item/permissions/requestApproval", params: {
      threadId: "thread-1", itemId: "permission", permissions: { network: { enabled: true } },
    } });
    await session.handle(sender, { type: "approve_tool", id: "allow", tool_call_id: "permission", decision: "allow" });
    expect(client.respond).toHaveBeenCalledWith(9, { permissions: { network: { enabled: true } }, scope: "turn" });
  });

  test("pending approvals and questions reappear after a phone reconnect", async () => {
    await session.start();
    client.emit("request", { id: 10, method: "item/commandExecution/requestApproval", params: { threadId: "thread-1", itemId: "pending" } });
    client.emit("request", { id: 11, method: "item/tool/requestUserInput", params: { threadId: "thread-1", itemId: "question", questions: [
      { id: "choice", header: "Choice", question: "Which folder?", isOther: true, options: [{ label: "Project", description: "Use project" }] },
    ] } });
    await session.handle(sender, { type: "session_sync", id: "reconnect" });
    expect(replies).toContainEqual(expect.objectContaining({ type: "tool_request", tool_call_id: "pending" }));
    expect(replies).toContainEqual(expect.objectContaining({ type: "extension_ui_request", id: "codex_question_11" }));
    await session.handle(sender, { type: "extension_ui_response", id: "codex_question_11", ask: {
      flow_id: "codex_question_11", kind: "answer", answers: { choice: { values: ["__other__"], customText: "/chosen/folder" } },
    } });
    expect(client.respond).toHaveBeenCalledWith(11, { answers: { choice: { answers: ["/chosen/folder"] } } });
  });

  test("a second phone can synchronize a partially streamed response", async () => {
    await session.start();
    await session.handle(sender, { type: "user_message", id: "m", text: "Hello" });
    client.emit("notification", "item/agentMessage/delta", { threadId: "thread-1", itemId: "answer", delta: "Still working" });
    await session.handle(sender, { type: "session_sync", id: "second-phone" });
    expect(replies).toContainEqual(expect.objectContaining({ type: "session_history", events: expect.arrayContaining([
      expect.objectContaining({ type: "agent_message", text: "Still working" }),
    ]) }));
  });

  test("resumes the saved thread and returns all history even when an old app asks for one event", async () => {
    const events: SessionHistoryEvent[] = Array.from({ length: 90 }, (_, index) => ({ ts: index, type: "user_input", id: String(index), text: String(index) }));
    writeFileSync(join(root, "state.json"), JSON.stringify({ threadId: "thread-1", startedAt: 42, events }));
    await session.start();
    expect(client.request).toHaveBeenCalledWith("thread/resume", { threadId: "thread-1", cwd: root });
    await session.handle(sender, { type: "session_sync", id: "history", limit: 1 });
    const history = replies.find((message) => message.type === "session_history");
    expect(history?.type === "session_history" && history.events).toHaveLength(90);
  });

  test("unknown server requests are rejected rather than silently approved", async () => {
    await session.start();
    client.emit("request", { id: 99, method: "future/requestApproval", params: { threadId: "thread-1" } });
    expect(client.rejectRequest).toHaveBeenCalledWith(99, expect.stringContaining("Unsupported"));
    expect(client.respond).not.toHaveBeenCalled();
  });
});
