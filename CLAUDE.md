# Showdown — project guide

A 2D turn-based iPhone game (SwiftUI), inspired by *Shogun Showdown*. A linear 10-cell arena where the
player and enemies take turns. Player has HP + stamina; actions are Move, Attack, Skip (regain stamina),
and Turn (free, flips facing). Clear 3 waves to win; 0 HP = lose.

## Layout
- `Showdown/ShowdownApp.swift` — `@main` app entry.
- `Showdown/Game.swift` — model layer: `GameState: ObservableObject`, `Combatant`, `Facing`, turn/stamina/
  enemy-AI/wave logic. **Foundation-only — do not import SwiftUI here.**
- `Showdown/GameView.swift` — all UI (arena, sprites, HP/stamina bars, controls, overlays).
- `Showdown.xcodeproj` — single iOS app target. Bundle id `net.leochen.Showdown`, deployment iOS 17+.
  Uses a file-system-synchronized group: new files under `Showdown/` are picked up automatically.

## The 3-agent development workflow (use for every change)
Roles (see `.claude/agents/`):
- **Program Manager** = the main session (`program-manager.md`). Plans, opens the issue, delegates, tracks,
  decides "done." Does not write feature code.
- **Coder** (`coder.md`, Opus) — implements one scoped task; never exceeds scope; self-checks with a sim build.
- **Reviewer** (`reviewer.md`, **Sonnet** — a different model) — independent, read-only review + runs verify.

Run a change with **`/feature <description>`** (handles features and fixes). Pipeline:
**issue (with risk plan) → branch → coder → reviewer → fix loop → `scripts/verify.sh` → `scripts/bump.sh`
→ `CHANGELOG.md` → commit + PR (closes #N) → tag.** Even without `/feature`, follow this process by default.

## Invariants (must always hold)
1. **Simulator-runnable:** `scripts/verify.sh` builds, launches, and screenshots in the iOS Simulator.
2. **Device-buildable:** the same script compiles for a generic iOS device (signed if an Apple ID cert
   exists, otherwise an unsigned device compile). Never break device buildability or signing config.
3. **Minimal scope:** implement exactly what's requested; file separate issues for anything else.
4. **Versioned + documented:** every change bumps the version (minor=feature, patch=fix) and adds one
   concise `CHANGELOG.md` line.

## Key commands
- Verify (sim run + device build-check): `scripts/verify.sh`
- Bump version + changelog: `scripts/bump.sh <major|minor|patch> "summary"`
- Manual simulator build: `xcodebuild -project Showdown.xcodeproj -scheme Showdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build`

## Notes / known constraints
- **GitHub** issue/PR steps need `gh auth login` (one-time, user). Until then the workflow runs locally and
  skips issue/PR creation.
- **Physical-device install** needs your Apple ID added in Xcode (Settings → Accounts) and your Team selected
  under Signing & Capabilities. The workflow keeps the app device-*buildable*; the final tap-to-install is
  done from Xcode.
- Git commit messages end with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
