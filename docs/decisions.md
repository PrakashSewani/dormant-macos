# Decisions

Append-only log of settled decisions. New entries get the next number, a date, and a sentence of
context. If a decision is reversed, add a new entry that supersedes the old one — never edit
history. The agent records decisions here **before** implementing them (see `AGENTS.md`, rule 2).

## D-001: Stack selection — native Swift + Xcode, zero third-party runtime deps

**Date:** 2026-09-26

**Context:** Dormant is a local-first macOS developer utility (menu bar app + Finder integration,
SQLite-backed project registry, local compressed archive store). Chosen with the human via the
`project-bootstrap` skill; the human selected the full-Xcode toolchain.

**Decision:**

- **Language / toolchain:** Swift 6.4 (swift-driver 1.168.6, swiftlang-6.4.0.34.1) on macOS 27.0,
  built with Xcode 27.0 (build 27A266a) — resolved live 2026-09-26 via `xcodebuild -version`.
  Swift 5 language mode (`SWIFT_VERSION: 5.0`) on the 6.4 compiler. Deployment target: macOS 14.0.
- **UI:** SwiftUI for the main window, dialogs, and `MenuBarExtra` menu bar item; AppKit where
  SwiftUI doesn't reach (Finder Sync, `NSWorkspace`).
- **Finder integration:** Finder Sync extension (`com.apple.FinderSync` appex) providing the
  inline "Dormant ▸" context submenu; destructive actions route to the app via a `dormant://` URL
  scheme so confirmation UI always runs in the app.
- **Project / build management:** XcodeGen 2.46.0 (Homebrew) — `project.yml` is committed, the
  `.xcodeproj` is generated. Xcode builds the app and the embedded extension.
- **Storage:** system SQLite (libsqlite3) registry at `~/.dormant/registry.sqlite`; archive store
  at `~/.dormant/store/` holding gzip tarballs (`/usr/bin/tar`, bsdtar) of a project's core files.
  Git inspection shells out to the system `git`. No third-party runtime dependencies.
- **Tests:** Swift Testing (bundled with the toolchain), run by `xcodebuild test`.
- **Lint / format:** `swift-format` (bundled with the toolchain; invoked as `xcrun swift-format` —
  the bare binary is not on PATH).
- **Check command:** `Scripts/check.sh` — lint → `xcodegen generate` → build → test. Definition of
  done for every change; CI runs exactly it.
- **CI:** GitHub Actions on the `macos-26` runner image (GA since 2026-02; `macos-latest` now
  points at it), `actions/checkout@v7.0.1`, installing XcodeGen via Homebrew.
- **Deployment target(s):** none. Local ad-hoc-signed builds only — no certificates, signing,
  notarization, or store submission (explicit product constraint). The manual release path lives
  in `.commandcode/skills/ship-release`.

**Considered and rejected:**

- **Electron / Tauri / cross-platform desktop kit** — Finder Sync and native menu bar status
  items are Apple-only; you'd still write Swift. Two stacks for zero gain.
- **Rust core + Swift shell** — a cross-language boundary in a Mac-only app, for no user benefit.
- **Command Line Tools-only SwiftPM build** (hand-assembled `.app`/`.appex`, ad-hoc signing) —
  avoids the Xcode install but is a nonstandard bundle pipeline Apple doesn't document for Finder
  Sync. Human chose full Xcode instead.
- **Finder Quick Action / Services menu** instead of a Finder Sync extension — simpler, but it
  lives in "Services", not the inline "Dormant ▸" submenu the product calls for.
- **Third-party libs (GRDB, libgit2, zstd, logging kits)** — system libsqlite3, `git`, and bsdtar
  cover every need; zero runtime deps keeps the build unbreakable and auditable.
- **tar.zst archives** — zstd ships on no stock macOS; gzip tarballs are universal and let the
  user inspect their own archive with stock tools.

**Cost / risk:** the dev Mac needs Xcode (~15 GB, in progress at decision time); ad-hoc signing
means the Finder extension may need a one-time enable in System Settings; the Finder Sync
app↔extension plumbing is the least-documented part of the build; CI runs macOS 26 / Xcode 26–27
while the dev Mac is macOS 27 — the macOS 14 deployment target keeps that gap benign.

## D-002: Branching and CI model — `dev` is the work branch, `main` is the release branch

**Date:** 2026-09-26

**Context:** Set by the human right after bootstrap: keep day-to-day work off `main`, and let the
CI weight follow the branch.

**Decision:**

- `dev` is the default work branch. Every change lands on `dev` through a pull request
  (work branch → PR → merge into `dev`).
- `main` is the release branch. Release tags (`v*`) are cut from `main` only, and full CI runs on
  pushes to `main` (`.github/workflows/ci.yml`).
- PRs run the check command (`Scripts/check.sh`) against any base; a green PR build is the merge
  gate into `dev`.
- The GitHub default branch is set to `dev` by the human.

**Considered and rejected:**

- **Trunk-only development on `main`** — mixes release state with work in progress.
- **Per-version release branches** — overkill for a local-first utility.
- **Full CI on every push to `dev`** — PR checks are the gate; runner time is better spent on
  `main`.

**Cost / risk:** `dev` → `main` merges (PR) are the only path to a release; tags must be cut from
`main` (recorded in the ship-release skill).
