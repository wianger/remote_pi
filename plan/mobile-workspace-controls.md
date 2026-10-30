# Mobile workspace controls

Delete removes a conversation from this phone and clears its cached messages.
Computer history files and running agents are retained. Persist local tombstones
by computer and logical conversation id; incoming room snapshots cannot recreate
deleted rows. Explicitly reopening a workspace restores that conversation.

Replace All/Working chips with a persisted workspace selector keyed by computer
and directory. The list shows the selected directory's conversations. The input
always exposes Send (disabled for empty content) with a separate voice button.

Context usage is a read-only query: used tokens, context window and percentage.
Pi uses the public SDK getContextUsage; Codex uses the last token-usage report,
never the cumulative billing total. Unknown usage stays unknown. No prompt or
system instructions are transferred. Existing relay and auth stay unchanged.

Verify deletion survives refresh/relaunch and late frames cannot refill the
cache; workspace switching and sending/voice on phone-sized layouts; context
request correlation, unavailable/offline states and both agent adapters. Build
the next signed Android version and publish through the development release
channel after analysis and tests pass. No new dependencies or iOS changes.
