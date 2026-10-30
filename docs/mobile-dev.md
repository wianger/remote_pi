# Personal Android development build

Development branch: `codex/mobile-sessions-ui-20261029`. Do not merge or push
these personal build settings to `main`.

The supported custom mobile target is Android only.

This build adds a chat workspace with a session sidebar and a **New session**
screen. Choose a paired computer, browse its directories, and open Pi or Codex.
If a matching live session exists, it is reopened. Managed sessions resume their
conversation for that directory; Quick Actions → New session starts a fresh
conversation. A computer must already have an online Remote Pi session to serve
the directory browser. The computer must stay awake and connected.

## Computer support

Build and install the extension from this branch, using Node 20+ and pnpm:

```sh
cd pi-extension
pnpm install --frozen-lockfile
pnpm typecheck
pnpm test
pnpm build
pi install /absolute/path/to/remote_pi_mobile/pi-extension
```

Restart Pi, then run `/remote-pi start` (and `/remote-pi pair` for each new app).
An existing relay URL and computer identity are retained. Browse/open messages
are accepted only from paired owners. The session manager starts on demand;
this does not install a new Windows service or a login task.

Codex uses the computer's installed `codex app-server` and existing local
sign-in. It inherits the configured sandbox and approval policy. Paused command,
file, and permission requests require an explicit phone decision; permissions
are granted for one turn only. No new API key is embedded in the app. Launch Pi
from a terminal with the proxy environment it needs if direct Internet access
is unavailable. Multiple paired Android clients may view the same session.

Codex history is stored under `~/.pi/remote/codex-sessions/` on the computer.
New app-created threads and previously saved managed threads are supported;
this version does not import all pre-existing Codex desktop/CLI threads.

## Android from Windows / Scoop

The personal app id is `dev.wianger.remotepi`, displayed as **Remote Pi Dev**.
It can coexist with the upstream app. Pair it separately and configure your
relay URL in Settings before scanning the pairing QR.

```powershell
scoop install extras/flutter@3.44.4 main/android-clt java/temurin17-jdk
flutter config --jdk-dir C:\Scoop\apps\temurin17-jdk\current
flutter config --android-sdk C:\Scoop\apps\android-clt\current
# Accept the SDK licences once, then:
.\scripts\build-mobile-windows.ps1
# Optional proxy for Gradle downloads:
.\scripts\build-mobile-windows.ps1 -ProxyUrl http://127.0.0.1:7897
```

For a WSL checkout, copy the script to a local Windows directory and pass
`-SourceApp \\wsl.localhost\Ubuntu-26.04\home\wiang\remote_pi_mobile\app`.
The build runs from a local Windows snapshot because Gradle does not reliably
support UNC working directories. The output is
`~/Downloads/RemotePi-Dev-Android.apk` (ARM64).

The build script keeps a private signing key in
`%LOCALAPPDATA%\RemotePiMobileBuild\signing`, outside the repository. Its password
is encrypted with Windows DPAPI for the current Windows user. Keep this key and
metadata for future updates; switching signing keys requires reinstalling the
app. The generated plaintext Gradle signing properties are removed after each
build. Never commit signing material, pairing state, VPN scripts or auth keys.

## Validation

For screenshots of the current Android UI with demonstration sessions, run
`scripts/preview-mobile-windows.ps1` from Windows (optional
`-ProxyUrl http://127.0.0.1:7897`). This uses the production Flutter widgets
with fixture ViewModels, without pairing or contacting an agent. It writes
`overview.png`, `home.png`, `chat.png`, `sessions.png`, `new-session.png` and
`activity-details.png` and `agent-picker.png` under
`~/Downloads/RemotePi-UI-Preview`. The script only downloads the checked Inter
font if it is not already cached; the widget renderer itself runs offline.
The manual preview test is skipped in ordinary test runs.

Use `-Theme light` for the warm light palette; `-Theme dark` is the default.
Supply a separate `-OutputDirectory` to keep both sets of screenshots. The
workspace grouping and conversation design are described in
`plan/android-workspace-design.md`.

The agent field opens a searchable list populated by the selected computer.
Agent ids, names, descriptions and availability come from its catalog; the
mobile UI does not require an enum update for a newer host's agent id. Only Pi
and Codex adapters are implemented today. See `plan/agent-catalog-picker.md`.

Thinking activities need the matching development extension on the computer.
The Android app still connects to an official extension for the features that
extension publishes; an older extension does not publish thinking snapshots.
Building or previewing the app does not activate the development extension.

```sh
cd pi-extension
pnpm typecheck && pnpm test && pnpm build
cd ../app
flutter pub get
flutter analyze
flutter test --concurrency=1
```

When testing a copied Windows snapshot, also copy
`.orchestration/contracts/fixtures` beside `app`. The macOS-only sound scale
test is skipped on other hosts. For an optional phone-sized folder chooser
preview, set `REMOTE_PI_PREVIEW_DIR` and run
`flutter test test/ui/workspaces/new_session_page_test.dart`.
