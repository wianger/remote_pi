# Context ring and scope selectors

Replace the chat context gauge with a determinate percentage ring, preserving
the token detail sheet. Fetch on opening/reconnecting, after a completed turn
or idle message update, and on app resume. Do not poll on streaming deltas.
Unknown or offline usage must not look like zero. Keep usage scoped to the
existing keyed chat provider and discard requests from disposed views.

Separate the sidebar controls visually and in interaction:
- Device: prominent monitor card opening a bottom sheet of paired computers.
- Workspace: compact folder/path row opening an anchored directory menu.

Keep the existing device/workspace selection persistence, session filtering,
pairing, Android identity and signing certificate. No extension or iOS changes.
Verify automatic usage refresh, unknown/zero/overflow ratios, existing selection
and deletion flows, narrow light/dark previews, analysis and signed APK updates.
