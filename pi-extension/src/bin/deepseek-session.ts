#!/usr/bin/env node
import { runDeepSeekHost } from "../deepseek/host.js";

runDeepSeekHost().catch((error: unknown) => {
  process.stderr.write(
    `[remote-pi] DeepSeek Harness could not start: ${
      error instanceof Error ? error.message : "unknown error"
    }\n`,
  );
  process.exitCode = 1;
});
