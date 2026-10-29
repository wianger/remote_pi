# Custom Android client

Requested scope:
- One Android client for Pixel, centered on chat with a session sidebar.
- Browse folders on a paired computer and open Pi or Codex in the selected folder.
- Keep existing Pi features, pairings, multi-device event broadcasts and the local full-history patch.

Implementation:
- Add authenticated workspace browse/open messages over the existing owner channel.
- Reuse the per-user supervisor; starting from mobile does not install an OS login service.
- Keep Pi daemon ids stable. Give Codex its own daemon id and named room per folder.
- Run Codex through its local app-server stdio protocol and existing computer sign-in.
- Bridge streaming, history, tool events, approval requests and user questions to the mobile protocol.
- Use a separate Android app identifier so custom builds can coexist with the installed official app.

Build and device validation:
- Windows Flutter 3.44.4, Android command-line tools and Java 17 installed with Scoop.
- Build and test Android locally, and verify the APK signature.
- Keep the inherited iOS project unchanged; custom mobile support is Android only.
- Verify actual Android device behavior; record any remaining installation limitation accurately.
