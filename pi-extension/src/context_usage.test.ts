import { describe, expect, test } from "vitest";
import { contextUsageSnapshot, handleContextUsage } from "./context_usage.js";
import { decodeServer } from "./protocol/codec.js";
import type { ServerMessage } from "./protocol/types.js";
describe("context usage", () => {
  test("reports the public SDK estimate without transferring prompt contents", () => {
    const replies: ServerMessage[] = [];
    handleContextUsage({ getContextUsage: () => ({ tokens: 80_000, contextWindow: 200_000, percent: 40 }) },
      { send: (message) => replies.push(message) }, "usage-request");
    expect(replies).toEqual([{ type: "context_usage", in_reply_to: "usage-request", tokens: 80_000,
      context_window: 200_000, percent: 40, source: "pi" }]);
    expect(decodeServer(JSON.stringify(replies[0]))).toEqual(replies[0]);
  });
  test("unreported tokens remain unknown, while zero is a valid reported value", () => {
    expect(contextUsageSnapshot(null, 200_000)).toEqual({ tokens: null, context_window: 200_000, percent: null });
    expect(contextUsageSnapshot(0, 200_000).percent).toBe(0);
    expect(contextUsageSnapshot(Infinity, NaN)).toEqual({ tokens: null, context_window: null, percent: null });
  });
  test("stale contexts cannot crash the relay callback", () => {
    const replies: ServerMessage[] = [];
    handleContextUsage({ getContextUsage() { throw new Error("stale context"); } },
      { send: (message) => replies.push(message) }, "stale");
    expect(replies[0]).toMatchObject({ type: "context_usage", tokens: null, context_window: null });
  });
});
