import { expect, test } from "vitest";
import { historyFrames } from "./history.js";
import type { SessionHistoryEvent } from "./types.js";

test("large UTF-8 histories preserve every event in relay-safe ordered frames", () => {
  const events: SessionHistoryEvent[] = Array.from({ length: 100 }, (_, i) => ({
    type: "user_input", id: String(i), ts: i, text: "中文".repeat(10_000),
  }));
  const frames = historyFrames({ in_reply_to: "sync", session_started_at: 1, events, truncated: false });
  expect(frames.length).toBeGreaterThan(1);
  expect(frames.flatMap((f) => f.events)).toEqual(events);
  expect(frames.filter((f) => f.eos)).toEqual([frames.at(-1)]);
  for (const frame of frames) {
    expect(Buffer.byteLength(JSON.stringify(frame), "utf8")).toBeLessThan(1024 * 1024);
  }
});

test("a large streaming cursor appears once, on the final bounded frame", () => {
  const frames = historyFrames({ in_reply_to: "sync", session_started_at: 1, truncated: false,
    events: [{ type: "user_input", id: "image", ts: 1, text: "image",
      images: [{ mime: "image/jpeg", data: "A".repeat(1600 * 1024) }] }],
    streaming: { in_reply_to: "image", text: "x".repeat(2 * 1024 * 1024) } });
  expect(frames).toHaveLength(2);
  expect(frames[0]).not.toHaveProperty("streaming");
  expect(frames[1]).toMatchObject({ eos: true, events: [], streaming: { in_reply_to: "image" } });
  for (const frame of frames) expect(Buffer.byteLength(JSON.stringify(frame))).toBeLessThan(2.8 * 1024 * 1024);
});

test("empty histories finish, and oversized individual events fail before transmission", () => {
  expect(historyFrames({ in_reply_to: "s", session_started_at: 1, events: [], truncated: false }))
    .toEqual([{ type: "session_history", in_reply_to: "s", session_started_at: 1, events: [], eos: true, truncated: false }]);
  expect(() => historyFrames({ in_reply_to: "s", session_started_at: 1, truncated: false,
    events: [{ type: "user_input", id: "large", ts: 1, text: "x".repeat(4 * 1024 * 1024) }] })).toThrow(/too large/);
});

test("one large event below the decoded relay ceiling is still supported", () => {
  const text = "x".repeat(3 * 1024 * 1024);
  const frames = historyFrames({ in_reply_to: "s", session_started_at: 1, truncated: false,
    events: [{ type: "user_input", id: "large-but-valid", ts: 1, text }] });
  expect(frames).toHaveLength(1);
  expect(frames[0]!.events[0]).toMatchObject({ text });
  expect(Buffer.byteLength(JSON.stringify(frames[0]))).toBeLessThan(4 * 1024 * 1024);
});