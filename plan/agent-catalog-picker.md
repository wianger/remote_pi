# Extensible Android agent picker

Replace the two-segment Pi/Codex control with a searchable bottom sheet. The
field shows the current agent; list rows show the computer's display name,
description, availability/reason and selected state. The list scrolls lazily
and remains usable with the phone keyboard.

The mobile domain carries stable string ids and metadata rather than an enum.
Decode every valid catalog entry, including ids introduced by a future host.
Retain unavailable entries for explanation, disable their selection/opening,
and reconcile selection against refreshed metadata. Never use a future id to
reattach a Pi room through the old Pi/Codex name heuristic; ask the host to
resolve those sessions instead.

The host maintains one catalog of implemented adapters for discovery, labels
and request validation. Only Pi and Codex are registered today. Adding a real
agent still requires its computer-side adapter/daemon integration and tests;
registering a display name alone does not implement a runner. The mobile picker
needs no additional tabs or enum members when a newer host adds an agent.

Validate future ids and unavailable metadata in the decoder, selection and
open flow; a 12-entry searchable phone list with keyboard insets; directory
navigation; host discovery and unsupported-id rejection. Render the normal
two-agent catalog in light/dark previews, without implying extra adapters exist.

During Android release builds, close the signing properties input stream so
the generated plaintext file can be removed even while the Gradle daemon lives.
