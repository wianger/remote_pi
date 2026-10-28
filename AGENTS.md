# Development branch rules

The owner requires all local and remote development to stay on development
branches. The current branch is `codex/mobile-sessions-ui-20261029`.

- Before editing or committing, confirm the current branch and working tree.
- Do not edit, commit, merge, reset, or push `main` without a new explicit owner
  instruction. Preserve the separate original checkout and its existing work.
- Push explicit development branch refs. The original WSL checkout shares a
  Git directory with this worktree; its `HEAD` belongs to a different worktree.
- The Windows clone at `C:\Users\26928\source\remote_pi_mobile` tracks this same
  development branch. Keep updates fast-forward only and preserve local work.
- `%LOCALAPPDATA%\RemotePiMobileBuild\app` is a generated build snapshot. Make
  source changes in a Git checkout, then copy them into that snapshot.

Read the relevant layer's `CLAUDE.md` before changing application code. Use
pnpm for the TypeScript extension and Flutter for the mobile app. Build details
and validation commands are in `docs/mobile-dev.md`.

Keep personal Android signing keys, Apple credentials, pairing state, VPN
scripts and auth keys outside the repository. Personal Android and iOS builds
use `dev.wianger.remotepi` so they can coexist with the upstream app.
