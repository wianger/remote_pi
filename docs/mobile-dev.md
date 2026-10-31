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
`~/Downloads/RemotePi-UI-Preview`. The renderer loads the same bundled font
manifest as the APK and runs offline. The helper caches a checksum-verified
OFL Noto Sans CJK font to emulate Android's system fallback in the desktop
renderer; this preview-only font is not shipped in the APK. The helper accepts
`-FlutterRoot` if Scoop's `current` link is unavailable.
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

## Recovery behavior

Use the matching development extension and Android APK for history fragments
and Codex cursor restoration. Pi and Codex now share byte-bounded history
batching; a single event above the supported frame size returns a clear error.
Codex interrupted turns close outstanding approvals/questions on all phones;
starting a new thread cannot replay their old requests. Batch start/restart
retains each agent's registered name, including Pi and Codex in one directory.

Directory requests are invalidated when the user cancels or changes selection.
Connection switches and restoration run in order, so a slow earlier connection
cannot later replace the restored room or send its request to another computer.
Restoration can wait for the bounded in-flight connection attempt to finish.
Building these changes does not change the active official Pi installation.

## Bundled fonts

The Android UI uses Geist for controls, input and the wordmark, Source Serif 4
for assistant prose, and Geist Mono for code, commands and paths. This is an
open approximation of the Claude-like typography. All fonts are bundled under
SIL OFL 1.1, including original copyright notices; no runtime font fetch is
required. CJK falls back to the device's installed sans fonts. Weight, italics,
font size preferences and light/dark colors remain supported. The license
notices are registered with Flutter's license page and shipped as APK assets.
Pinned sources and SHA-256 checksums are in `app/assets/fonts/sources.json`.


## GitHub development updates

The Android app's Settings -> App updates -> Check for updates reads the fork's
published GitHub Releases, including its development prereleases. Only tags
`android-dev-v<version>+<versionCode>` with `RemotePi-Dev-Android.apk` are accepted.
It shows release notes and opens the signed APK download in the browser; Android
asks the user to install it over the existing app. No uninstall is needed.
API/network failures are shown separately from an up-to-date result. GitHub's
public API is used without storing a GitHub token in the mobile app.

For each release, increment `app/pubspec.yaml`'s build number (including rebuilds
of the same visible version), build with the existing private key, test, commit
and push the explicit development branch. Then, from the clean Windows checkout:

```powershell
scripts/publish-android-dev-windows.ps1 -Apk "$env:USERPROFILE/Downloads/RemotePi-Dev-Android.apk" -NotesFile "$env:TEMP/remote-pi-release-notes.md" -Publish
```

Without `-Publish` the script creates a draft. It checks the pushed development
commit, package id, versionCode/versionName, signing certificate, monotonically
increasing version code and uploaded assets. Personal signing material stays on
Windows and is never uploaded to GitHub. The old app needs one initial cover
installation to gain this update entry. Future computer extension changes still
need `git pull --ff-only`, `pnpm build` and Pi `/reload` (or restart).

## Resumed Pi conversations

Pi publishes a hashed SDK session id as part of its opaque room identifier.
Mobile groups a daemon and a desktop resume of that exact conversation into one
row and one message cache, preferring a live/working route, then the interactive
route. Different conversations in the same directory remain independent, and
commands always target one physical room. The existing relay needs no rebuild.
Both Pi processes must load the new extension before this identity is available.
Native `resume` still starts a separate Pi process; it does not attach its TUI to
the supervisor's process. This change groups conversation views and routing,
without merging the two processes or their in-memory agent state.

For an already-running phone-created Pi daemon, wait until its turn finishes,
then use `/remote-pi daemon restart <id>` (or omit the id to restart all).
This reloads the development extension in the daemon as well as the desktop.


## Mobile controls (1.2.2 / Android build 10)

The sidebar Workspace selector switches between paired computer/directory pairs.
Only that workspace's conversations are listed; the selected workspace persists.
Each session's menu (or long press) offers Delete from phone. It removes the row
and clears this phone's message/index/runtime cache, without stopping the agent
or deleting computer history. Local tombstones prevent relay refreshes and app
relaunch from recreating deleted rows. Open that directory explicitly to restore
its conversation on this phone. Different phones retain their own histories.

The composer always displays a Send arrow, disabled while empty or offline.
Voice dictation has a separate button; existing hold-to-talk, images, steering
and Stop controls remain available.

The chat toolbar's Context usage button opens used tokens, context window and
percentage with a refresh action. Pi reports the public SDK estimate. Codex uses
its last per-thread token-usage report rather than cumulative billed tokens.
Unknown tokens are displayed as Not reported. The matching computer extension
must be reloaded to answer this read-only query. No prompts are transferred.


## Device-first navigation and Baya (1.2.5 / build 13)

The custom Android app is named Baya. Select Device, then Workspace,
then a session in the sidebar. Paired devices without rooms remain selectable;
workspaces never include another device's paths. Each device remembers its
workspace, and changing selectors clears search without redirecting the active
chat. The prior combined workspace preference migrates on first load.

The weaverbird mark is defined in app/branding/baya-mark.svg, Flutter
AppMarkPainter and Android vector drawables. Its golden crown and weaving
thread represent gathering work into one place. The adaptive launcher keeps
the whole mark within its safe circle and has a monochrome variant for themed
icons. The Android id dev.wianger.remotepi,
private signing key and RemotePi-Dev-Android.apk release asset stay stable for
in-place updates. The GitHub repository, Pi commands and protocol names remain
Remote Pi for compatibility. No custom iOS changes are included.

## Apple-inspired controls (1.2.6 / build 14)

The Android shell borrows the hierarchy of Apple's current Liquid Glass design:
a diffused control layer for the chat toolbar, composer and session sidebar,
with bounded blur, soft depth, clear edges, capsule actions and Baya teal.
Chat prose, thinking, commands and output retain opaque reading surfaces.
Device -> Workspace -> Session navigation and all existing actions remain.

This is a Flutter treatment on Android, not Apple's native glass renderer.
High contrast uses opaque control fills without blur or shadows. Composer
action transitions respect reduced motion. Primary send/voice controls and
scope selectors provide at least 44 logical pixels of touch height.
The bundled Geist / Source Serif 4 / Geist Mono fonts are retained.

References:
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/videos/play/wwdc2026/102/

## Layered Baya artwork (1.2.7 / build 15)

The existing weaverbird now uses a directional teal tile, a pale raised bird,
gold gradients and restrained edge highlights. Welcome and sidebar marks share
the Flutter painter. Untiled glyphs and high contrast keep the flat treatment.

The SVG master and `app/branding/sync_android_icons.py` export the matching
Android background, foreground and pure monochrome vectors. The background
fills the system mask; the bird, thread and their small shadows remain inside
the launcher mask. Color and monochrome PNG fallbacks cover five densities.
There are no animation, runtime image downloads or new package dependencies.

Reference: https://developer.apple.com/design/human-interface-guidelines/app-icons

## Graphite and soft gold (1.2.8 / build 16)

The owner selected Graphite / Soft Gold from the palette proposals. The bird,
launcher and startup surface now share the graphite/ivory/gold composition.
The light and dark interface uses neutral primary actions, with gold reserved
for the bird and limited text details. Semantic status colors are retained.
Layer geometry, fonts, glass controls and session behavior are unchanged.

## Context ring and scope controls (1.2.9 / build 17)

The chat context button now displays a determinate usage ring and rounded
percentage, and still opens the precise token usage sheet. It refreshes on
connection, completed turns/idle message changes and app resume. Missing or
offline usage shows a dash rather than zero, and the arc is bounded at 100%.
Device selection uses a prominent monitor card and bottom sheet. Workspace
selection uses a flat folder/path row and an anchored menu showing full paths.
Both controls retain the existing scoped session list and saved selection.

## Small-window layout (1.2.10 / build 18)

The sidebar header (brand row, device and workspace switchers, new-session
button, search field and session label) now lives inside the scroll view, so
short windows such as split-screen panes scroll the header with the session
list instead of overflowing and squashing the list to zero height. The pair
and settings actions stay pinned at the bottom. In the chat header the status
label is wrapped with an ellipsis constraint, so "Reconnecting" and other
statuses no longer overflow at 320dp width with the XL font scale.

## Logical workspaces and command controls (1.2.11 / build 19)

Workspaces are now phone-side logical containers rather than directory
aliases. Create a workspace with **New workspace**, then start sessions in any
folders on that device; **New session** adds the resulting conversation to the
selected workspace. Opening a grouped session keeps that workspace selected.
Device and workspace use distinct controls, and the sidebar no longer has a
separate collapse button. Pair and Settings share one compact action row.

Session Rename, Info and Delete are available by long press. The chat header
menu offers Rename and Info, while Delete remains the phone-only cache removal.
Computer changes to an existing conversation no longer expose broker suffixes
such as `#2`. Paired connections adopt their persisted conversation room
immediately, so daemon and interactive Pi endpoints continue writing to the
same local history.

The About page now groups version information, GitHub update checks, project
and release links, licenses and contributor details in the FlClash-style
layout. Update state is no longer duplicated in Settings.

The composer keeps voice input and model/thinking controls available while a
text draft exists. Typing `/` opens agent commands, prompt templates and
skills in addition to built-in actions. Compact and fresh-session actions now
live in that slash palette instead of separate quick-action buttons.

Assistant turns expose one copy action on their final text segment. Consecutive
completed tool calls collapse into one Claude-mobile-style summary row with a
detail sheet; approval requests remain separate interactive cards. Context
usage requests correlate a Pi conversation's daemon and interactive endpoints
and reject late replies after switching to another conversation.
