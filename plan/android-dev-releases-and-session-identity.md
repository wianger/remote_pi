# Android development releases and resumed Pi sessions

The personal Android app checks published GitHub Releases in wianger/remote_pi.
Only tags android-dev-v<version>+<Android versionCode> and the signed asset
RemotePi-Dev-Android.apk belong to this update channel. Drafts, upstream app
releases, missing assets, and foreign download URLs are ignored. Settings has
a manual check, release notes and a browser APK download; Android confirms the
cover installation. Existing Dio, package_info_plus and url_launcher suffice.
The signing key stays on the owner's Windows computer. A local publish script
uploads a validated APK and checksums from an explicit development commit.

The mobile list currently shows physical relay rooms. A daemon Pi and a native
Pi resuming its JSONL are different processes but the same logical conversation.
New Pi room IDs carry a hash of the SDK session id and a separate instance
route: pi_<16-character session hash>_<d or i>_<12-character legacy room hash>.
The relay treats these as opaque strings and needs no deployment change. Routes
remain distinct: commands must never be broadcast to both Pi instances. Mobile
listing groups routes by actual session identity, scoped to each computer; live
and working routes take precedence, then interactive routes. Different session
ids in the same directory remain separate. Message caches use the logical id.
Legacy rooms and Codex routes preserve their existing behavior. This does not
turn native resume into an attachment to the daemon process.

Validation: GitHub API/parser and update action tests; actual same-session vs
different-session route regressions; legacy-room/cache coverage; Flutter analyze
and tests; extension typecheck/tests/build; signed versionCode increment; release
asset download/hash check. All work stays on codex/mobile-sessions-ui-20261029.
