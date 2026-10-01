# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.10] - 2026-10-01

### Added

- Git Clone into Folder in Dormant (Finder empty-space right-click): Dormant asks for the
  repository URL, clones into the clicked folder, registers the clone, and opens it in VS Code
  (D-020).
- Menu-bar quick actions: up to 10 projects with one-click Open, and Restore… for dormant ones
  (D-024).
- Savings summary bar with total reclaimable space and "Clean All…" batch clean, previewed per
  project and run only after one explicit confirm (D-022).
- Auto-archive suggestions: a quiet note and Review… dialog for projects idle 30+ days —
  suggestions only, nothing is archived automatically (D-023).
- Search field and gray "Stale" badges (no commit in 30+ days) in the project list (D-021).
- Liquid Glass interface with SF Symbols across toolbar, rows, menus and dialogs, and the brand
  mark as the menu-bar icon (D-018).

- Menu bar app and Finder "Dormant ▸" hover submenu with Clean, Archive, Restore, and Import
  Folder in Dormant actions on a folder, and Open Directory in Dormant on empty space, routed to
  the app via `dormant://` URLs (works with the window closed); Open, Project Info, and Open
  Repository live in the app's project list (D-016, D-017).
- Import Folder in Dormant: scan the selected Finder folder for projects (the app's Scan
  function) and register them in the local registry.
- Open Directory in Dormant: import the folder being browsed and open the app with that
  directory selected (D-017).
- Directories: imported folders (e.g. Work vs Personal project roots) are tracked as directories;
  the app groups projects under their deepest containing directory and shows how much disk each
  directory eats — the whole folder on disk (D-017).
- Clean: preview of regenerable development state with per-path sizes and total reclaim, then
  confirmed removal — driven by an ecosystem-scoped classification rule table; anything not
  confidently classified is never removed.
- Archive: uncommitted-changes warning with counts, regenerable clean, verified gzip tarball plus
  `manifest.json` in `~/.dormant/store/`, working copy removed only after verification.
- Restore: extraction to the original or a chosen path, checksum verification against the
  manifest, then detected dependency install commands shown and confirmed before running.
- SQLite project registry (`~/.dormant/registry.sqlite`) and project scanning of chosen roots.
- Project Info view (local vs core vs regenerable sizes, git state, remote, last commit) and
  Open in VS Code (`code .`; a hard error when `code` is not installed — D-015).
- Repository scaffold from the `template-app-plus-site` template (docs-first skeleton; stack
  chosen at bootstrap).
- Promo site (Eleventy, `site/`) explaining the product and pointing at the download.
- Homebrew tap install (`PrakashSewani/homebrew-tap`): `brew tap PrakashSewani/tap && brew
  install --cask dormant` (D-010); distribution stays signing-free per D-001.

### Changed

- Deployment target raised to macOS 26 for the Liquid Glass interface; installs require macOS 26+
  (D-018).
- Release artifact is now `Dormant-v<version>.dmg` with a drag-to-Applications window; the
  Homebrew cask installs from the DMG (D-019).
- Dialog buttons have consistent minimum sizing and spacing (D-018).
- Registry schema v2: new `directories` table (D-017); existing v1 databases upgrade in place
  with data intact.
- Dependency install commands (npm, pnpm, yarn, bun, uv, poetry, python3, cargo, dotnet, go) now
  resolve their executables from hardcoded, known install locations (nvm, Homebrew, volta, bun,
  cargo, asdf shims, `~/.local/bin`, …) instead of the GUI app's minimal `PATH`; a missing tool
  fails with a clear error listing where Dormant looked (D-015).
- Release flow: release PRs from `dev` to `main` with exactly one `release:patch`,
  `release:minor`, or `release:major` label drive the version bump, `v<version>` tag, and GitHub
  release; unlabeled merges publish nothing.
