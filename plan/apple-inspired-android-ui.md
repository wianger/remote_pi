# Apple-inspired Baya controls on Android

Refine the existing Android chat and device -> workspace -> session navigation
using Apple's current Liquid Glass hierarchy. This is a Flutter interpretation,
not a native Apple material or a change to the supported platforms.

References checked on 2026-10-30:
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/videos/play/wwdc2026/102/
- https://developer.apple.com/design/human-interface-guidelines/toolbars

Use a restrained, diffused glass layer for the chat toolbar, composer and
sidebar. Clip blur to each control's bounds. Use clear edges, subtle highlights
and soft shadows rather than making chat prose, code or tool output transparent.
Align nested corners, use capsule actions and retain Baya's teal identity.
Keep the bundled open fonts and the reading-focused conversation layout.

Preserve pairing, session identity, deletion behavior, tool disclosures,
directory browsing, text sending, voice, steering, Stop and context usage.
Provide opaque high-contrast surfaces, respect reduced motion and keep touch
actions at least 44 logical pixels. Do not add dependencies or edit iOS.

Validate the material accessibility fallbacks, existing chat/navigation tests,
light/dark real-widget previews, Flutter analysis and signed Android build.
Publish with the existing package, signing key and GitHub update asset name.
