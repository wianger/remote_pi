import { EventEmitter } from "node:events";
import {
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import type {
  ServerMessage,
  SessionHistoryEvent,
} from "../protocol/types.js";
import type { PeerChannel } from "../transport/peer_channel.js";
import {
  type DeepSeekClientEvents,
  type DeepSeekServerRequest,
  type JsonObject,
} from "./client.js";
import { DeepSeekSession } from "./session.js";

const modelRoute = JSON.stringify([
  "deepseek-official",
  "deepseek-v4-pro",
]);

function configOptions(): JsonObject[] {
  return [
    {
      id: "model",
      name: "Model",
      category: "model",
      type: "select",
      currentValue: modelRoute,
      options: [
        {
          group: "deepseek-official",
          name: "DeepSeek",
          options: [
            {
              value: modelRoute,
              name: "DeepSeek V4 Pro",
              description: "DeepSeek's frontier coding model",
            },
            {
              value: JSON.stringify([
                "deepseek-official",
                "deepseek-v4-flash",
              ]),
              name: "DeepSeek V4 Flash",
            },
          ],
        },
      ],
    },
    {
      id: "reasoning_effort",
      name: "Reasoning effort",
      category: "thought_level",
      type: "select",
      currentValue: "high",
      options: [
        { value: "", name: "Provider default" },
        { value: "low", name: "Low" },
        { value: "medium", name: "Medium" },
        { value: "high", name: "High" },
      ],
    },
  ];
}

class FakeDeepSeek extends EventEmitter<DeepSeekClientEvents> {
  private promptSettled: ((value: unknown) => void) | null = null;
  private options = configOptions();
  start = vi.fn(async () => ({ supportsImages: true }));
  notify = vi.fn();
  respond = vi.fn();
  rejectRequest = vi.fn();
  close = vi.fn();
  request = vi.fn(async (
    method: string,
    params: JsonObject = {},
  ): Promise<unknown> => {
    if (method === "session/new") {
      return { sessionId: "deepseek-session-1", configOptions: this.options };
    }
    if (method === "session/resume") {
      return { configOptions: this.options };
    }
    if (method === "session/set_config_option") {
      this.options = this.options.map((raw) => {
        if (raw.id !== params.configId) return raw;
        return { ...raw, currentValue: params.value };
      });
      return { configOptions: this.options };
    }
    if (method === "session/prompt") {
      return new Promise((resolve) => {
        this.promptSettled = resolve;
      });
    }
    return {};
  });

  finishPrompt(stopReason = "end_turn"): void {
    this.promptSettled?.({ stopReason });
    this.promptSettled = null;
  }
}

describe("DeepSeek Harness mobile session bridge", () => {
  let root: string;
  let client: FakeDeepSeek;
  let broadcasts: ServerMessage[];
  let replies: ServerMessage[];
  let sender: PeerChannel;
  let session: DeepSeekSession;

  beforeEach(() => {
    root = mkdtempSync(join(tmpdir(), "remote-pi-deepseek-test-"));
    client = new FakeDeepSeek();
    broadcasts = [];
    replies = [];
    sender = { send: (message) => replies.push(message) };
    session = new DeepSeekSession({
      cwd: root,
      client,
      statePath: join(root, "state.json"),
      broadcast: (message) => broadcasts.push(message),
    });
  });

  afterEach(() => {
    session.close();
    if (
      dirname(root) !== realpathSync(tmpdir())
      || !basename(root).startsWith("remote-pi-deepseek-test-")
    ) {
      throw new Error("Unsafe test cleanup path.");
    }
    rmSync(root, { recursive: true, force: true });
  });

  test("starts ACP with the selected workspace and streams Chinese output", async () => {
    await session.start();
    const prompt = session.handle(sender, {
      type: "user_message",
      id: "phone-message",
      text: "你好",
    });
    await vi.waitFor(() => {
      expect(client.request).toHaveBeenCalledWith(
        "session/prompt",
        {
          sessionId: "deepseek-session-1",
          prompt: [{ type: "text", text: "你好" }],
        },
        0,
      );
    });
    client.emit("notification", "session/update", {
      sessionId: "deepseek-session-1",
      update: {
        sessionUpdate: "agent_thought_chunk",
        messageId: "reasoning-1",
        content: { type: "text", text: "Checking the project." },
      },
    });
    client.emit("notification", "session/update", {
      sessionId: "deepseek-session-1",
      update: {
        sessionUpdate: "agent_message_chunk",
        messageId: "answer-1",
        content: { type: "text", text: "你好，世界" },
      },
    });
    client.finishPrompt();
    await prompt;
    expect(session.isBusy).toBe(false);
    expect(broadcasts).toContainEqual(
      expect.objectContaining({
        type: "user_message",
        id: "phone-message",
      }),
    );
    expect(broadcasts).toContainEqual(
      expect.objectContaining({
        type: "agent_chunk",
        in_reply_to: "phone-message",
        delta: "你好，世界",
      }),
    );
    await session.handle(sender, { type: "session_sync", id: "sync", limit: 1 });
    const history = replies.find(
      (message) => message.type === "session_history",
    );
    expect(history?.type === "session_history" && history.events).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: "agent_thinking",
          text: "Checking the project.",
          complete: true,
        }),
        expect.objectContaining({
          type: "agent_message",
          text: "你好，世界",
        }),
      ]),
    );
  });

  test("maps opaque ACP model and reasoning choices back to the picker", async () => {
    await session.start();
    await session.handle(sender, { type: "list_models", id: "models" });
    const listed = replies.at(-1);
    expect(listed).toMatchObject({
      type: "models_list",
      in_reply_to: "models",
      current: {
        id: "deepseek-v4-pro",
        name: "DeepSeek V4 Pro",
        provider: "deepseek-official",
        reasoning: true,
        vision: true,
      },
    });

    await session.handle(sender, {
      type: "model_set",
      id: "pick-model",
      provider: "deepseek-official",
      model_id: "deepseek-v4-flash",
    });
    expect(client.request).toHaveBeenCalledWith(
      "session/set_config_option",
      {
        sessionId: "deepseek-session-1",
        configId: "model",
        value: JSON.stringify([
          "deepseek-official",
          "deepseek-v4-flash",
        ]),
      },
    );

    await session.handle(sender, {
      type: "thinking_set",
      id: "pick-effort",
      level: "medium",
    });
    expect(client.request).toHaveBeenCalledWith(
      "session/set_config_option",
      {
        sessionId: "deepseek-session-1",
        configId: "reasoning_effort",
        value: "medium",
      },
    );
  });

  test("requires an explicit one-shot permission decision", async () => {
    await session.start();
    const prompt = session.handle(sender, {
      type: "user_message",
      id: "permission-turn",
      text: "Run the tests",
    });
    await vi.waitFor(() => {
      expect(client.request).toHaveBeenCalledWith(
        "session/prompt",
        expect.any(Object),
        0,
      );
    });
    const request: DeepSeekServerRequest = {
      id: 42,
      method: "session/request_permission",
      params: {
        sessionId: "deepseek-session-1",
        toolCall: {
          toolCallId: "tool-1",
          title: "Run tests",
          name: "pwsh",
          rawInput: { command: "pnpm test" },
        },
        options: [
          {
            optionId: "allow-once",
            name: "Allow once",
            kind: "allow_once",
          },
          {
            optionId: "reject-once",
            name: "Reject",
            kind: "reject_once",
          },
        ],
      },
    };
    client.emit("request", request);
    expect(client.respond).not.toHaveBeenCalled();
    expect(broadcasts).toContainEqual(
      expect.objectContaining({
        type: "tool_request",
        tool_call_id: "tool-1",
        args: {
          command: "pnpm test",
          title: "Run tests",
          approval_required: true,
        },
      }),
    );
    await session.handle(sender, {
      type: "approve_tool",
      id: "allow",
      tool_call_id: "tool-1",
      decision: "allow",
    });
    expect(client.respond).toHaveBeenCalledExactlyOnceWith(42, {
      outcome: { outcome: "selected", optionId: "allow-once" },
    });
    client.finishPrompt();
    await prompt;
  });

  test("records ACP tool lifecycle and context usage", async () => {
    await session.start();
    const prompt = session.handle(sender, {
      type: "user_message",
      id: "tool-turn",
      text: "Inspect files",
    });
    await vi.waitFor(() => {
      expect(client.request).toHaveBeenCalledWith(
        "session/prompt",
        expect.any(Object),
        0,
      );
    });
    client.emit("notification", "session/update", {
      sessionId: "deepseek-session-1",
      update: {
        sessionUpdate: "tool_call",
        toolCallId: "tool-2",
        title: "Read project files",
        name: "list_files",
        kind: "read",
        status: "in_progress",
        rawInput: { path: root },
      },
    });
    client.emit("notification", "session/update", {
      sessionId: "deepseek-session-1",
      update: {
        sessionUpdate: "tool_call_update",
        toolCallId: "tool-2",
        status: "completed",
        content: [
          {
            type: "content",
            content: { type: "text", text: "12 files" },
          },
        ],
      },
    });
    client.emit("notification", "session/update", {
      sessionId: "deepseek-session-1",
      update: { sessionUpdate: "usage_update", used: 25_000, size: 100_000 },
    });
    client.finishPrompt();
    await prompt;
    await session.handle(sender, {
      type: "context_usage_get",
      id: "context",
    });
    expect(replies.at(-1)).toMatchObject({
      type: "context_usage",
      source: "deepseek",
      tokens: 25_000,
      context_window: 100_000,
      percent: 25,
    });
    await session.handle(sender, { type: "session_sync", id: "history" });
    const history = replies.find(
      (message) => message.type === "session_history",
    );
    expect(history?.type === "session_history" && history.events).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: "tool_request",
          tool_call_id: "tool-2",
          args: {
            path: root,
            title: "Read project files",
            kind: "read",
          },
        }),
        expect.objectContaining({
          type: "tool_result",
          tool_call_id: "tool-2",
          result: "12 files",
        }),
      ]),
    );
  });

  test("cancels through ACP and closes the working turn", async () => {
    await session.start();
    const prompt = session.handle(sender, {
      type: "user_message",
      id: "cancel-turn",
      text: "Keep going",
    });
    await vi.waitFor(() => {
      expect(client.request).toHaveBeenCalledWith(
        "session/prompt",
        expect.any(Object),
        0,
      );
    });
    await session.handle(sender, {
      type: "cancel",
      id: "cancel",
      target_id: "cancel-turn",
    });
    expect(client.notify).toHaveBeenCalledWith("session/cancel", {
      sessionId: "deepseek-session-1",
    });
    client.finishPrompt("cancelled");
    await prompt;
    expect(replies).toContainEqual({
      type: "cancelled",
      in_reply_to: "cancel",
      target_id: "cancel-turn",
    });
  });

  test("resumes the saved ACP id and replays the complete local transcript", async () => {
    const events: SessionHistoryEvent[] = Array.from(
      { length: 90 },
      (_, index) => ({
        ts: index,
        type: "user_input",
        id: String(index),
        text: String(index),
      }),
    );
    writeFileSync(join(root, "state.json"), JSON.stringify({
      sessionId: "deepseek-session-1",
      startedAt: 42,
      events,
      contextUsage: {
        tokens: 40_000,
        context_window: 200_000,
        percent: 20,
      },
    }));
    await session.start();
    expect(client.request).toHaveBeenCalledWith(
      "session/resume",
      {
        sessionId: "deepseek-session-1",
        cwd: root,
        mcpServers: [],
      },
      120_000,
    );
    await session.handle(sender, {
      type: "session_sync",
      id: "history",
      limit: 1,
    });
    const history = replies.find(
      (message) => message.type === "session_history",
    );
    expect(history?.type === "session_history" && history.events).toHaveLength(90);
    await session.handle(sender, {
      type: "context_usage_get",
      id: "context",
    });
    expect(replies.at(-1)).toMatchObject({
      tokens: 40_000,
      context_window: 200_000,
      source: "deepseek",
    });
  });

  test("rejects unsupported ACP client requests instead of auto-approving", async () => {
    await session.start();
    client.emit("request", {
      id: 99,
      method: "terminal/create",
      params: { sessionId: "deepseek-session-1" },
    });
    expect(client.rejectRequest).toHaveBeenCalledWith(
      99,
      expect.stringContaining("Unsupported"),
    );
    expect(client.respond).not.toHaveBeenCalled();
  });

  test("persists its own ACP session id without storing credentials", async () => {
    await session.start();
    const saved = JSON.parse(
      readFileSync(join(root, "state.json"), "utf8"),
    ) as Record<string, unknown>;
    expect(saved["sessionId"]).toBe("deepseek-session-1");
    expect(JSON.stringify(saved).toLowerCase()).not.toContain("api-key");
    expect(JSON.stringify(saved).toLowerCase()).not.toContain("authorization");
  });
});
