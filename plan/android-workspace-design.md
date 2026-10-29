# Android workspace and conversation design

The supported custom target remains Android. Development stays on
`codex/mobile-sessions-ui-20261029`; the active official installation is not
changed by a design preview.

## References

- [Herdr](https://herdr.dev/): computers, project workspaces and agent sessions
  belong in one navigation hierarchy, with working state visible at a glance.
- [Claude for Android](https://play.google.com/store/apps/details?id=com.anthropic.claude):
  a quiet conversation surface, rounded user messages, readable long responses
  and a multiline composer with its controls inside the input card.

These references guide the interaction and visual hierarchy. Remote Pi keeps
its own identity and the existing Pi/Codex integrations.

## Implementation

- Group existing rooms by computer, display the project name and agent, and
  filter to working sessions using actual room metadata. Do not infer blocked
  or completed state for other rooms when the protocol does not provide it.
- Make Home a workspace overview, with existing sessions and a folder/agent
  entry point. Reuse the same session-switching flow as the sidebar.
- Use warm neutral light and dark palettes. Use sans for navigation, serif for
  assistant prose, and monospace only for code, commands and paths.
- Keep tool results compact and expandable. Pending approvals stay expanded
  so their Allow once and Deny actions remain available.
- Keep send, steering, cancellation, queued messages, attachments, hold-to-talk
  and hardware keyboard behavior. Reorganize their existing controls into a
  two-row composer; model selection opens the existing Quick Actions sheet.
- Align short conversations below the header. Keep long histories lazy within
  the bounded viewport, with reversed scrolling and stable message keys. The
  preview test checks that a 4,000-message history mounts fewer than 80 reply
  widgets and initially shows the newest reply.

## Validation

Run Flutter analysis, the chat/input/tool widget tests and directory chooser
tests. Render actual Flutter widgets with demonstration sessions in both light
and dark themes, then inspect the exported screenshots. A phone installation
and real relay interaction are separate from this visual preview.
