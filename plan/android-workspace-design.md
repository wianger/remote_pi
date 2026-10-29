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
- [Claude thinking display](https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings):
  a separate, expandable thinking section above the response.

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
- Use quiet inline activity disclosures for commands, file operations and
  thinking, following Claude's mobile conversation hierarchy. Command details
  reveal arguments and scrollable output; failed operations retain emphasis.
- Keep provider-supplied thinking separate from assistant replies. The additive
  `agent_thinking` snapshot carries a stable block id, text and completion flag.
  Pi forwards explicit thinking blocks; Codex forwards its public summary only.
  No summary is invented when the agent supplies none. Start/completion and
  history replay update the same persisted row. This requires the corresponding
  development extension; the official runtime stays unchanged during previews.
- The folder chooser already browses the selected computer's directories:
  tap a folder to enter it, go home/up, filter, show hidden folders or type an
  absolute path, then open Pi/Codex in the current directory.
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

Thinking coverage also checks extension typechecking/build, Pi start/completion
frames and history order, Codex summary-only replay, and Flutter snapshot upsert,
completion and history persistence. The relay-state test waits for actual room
metadata events so a short fixed delay cannot hide a coalesced transition.
