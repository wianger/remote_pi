import { describe, expect, test } from "vitest";
import { isPairedOwner } from "./owner_host.js";

describe("non-Pi harness owner authorization", () => {
  const key = Buffer.alloc(32, 253);
  const standard = key.toString("base64");
  const urlSafe = key.toString("base64url");

  test("accepts a paired key across base64 encodings", () => {
    expect(isPairedOwner(standard, [{ remote_epk: urlSafe }])).toBe(true);
    expect(isPairedOwner(urlSafe, [{ remote_epk: standard }])).toBe(true);
  });

  test("does not authorize a different or revoked owner", () => {
    expect(isPairedOwner(Buffer.alloc(32, 1).toString("base64"), [{ remote_epk: standard }])).toBe(false);
    expect(isPairedOwner(standard, [])).toBe(false);
  });

  test("malformed sender and malformed records cannot match each other", () => {
    for (const sender of [null, "", "not-an-ed25519-key", {}, "abcd"]) {
      expect(isPairedOwner(sender, [{ remote_epk: "invalid" }])).toBe(false);
    }
  });
});
