# Custom mobile client

Requested scope:
- One Flutter client for Pixel and iPhone, centered on chat with a session sidebar.
- Browse folders on a paired computer and open Pi or Codex in the selected folder.
- Keep existing Pi features, pairings, multi-device event broadcasts and the local full-history patch.

Implementation:
- Add authenticated workspace browse/open messages over the existing owner channel.
- Reuse the per-user supervisor; starting from mobile does not install an OS login service.
- Keep Pi daemon ids stable. Give Codex its own daemon id and named room per folder.
- Run Codex through its local app-server stdio protocol and existing computer sign-in.
- Bridge streaming, history, tool events, approval requests and user questions to the mobile protocol.
- Use separate custom app identifiers so custom builds can coexist with the installed official app.

Build and device validation:
- Windows Flutter 3.44.4, Android command-line tools and Java 17 installed with Scoop.
- Build/test Android locally; build an unsigned iOS artifact with a macOS CI runner.
- The user has no Mac or paid Apple Developer account. Prepare a Windows personal-signing installation flow;
  account sign-in and iPhone trust/developer-mode steps are performed by the user.
- Verify both artifacts and actual device behavior; record any remaining installation limitation accurately.
