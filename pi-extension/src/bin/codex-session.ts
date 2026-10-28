#!/usr/bin/env node
import { runCodexHost } from "../codex/host.js";

runCodexHost().catch((error: unknown) => {
  process.stderr.write(`[remote-pi] Codex could not start: ${error instanceof Error ? error.message : "unknown error"}\n`);
  process.exitCode = 1;
});
