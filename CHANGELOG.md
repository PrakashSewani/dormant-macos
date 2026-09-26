# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Menu bar app and Finder "Dormant ▸" submenu with Open, Clean, Archive, Restore, Project Info,
  and Open Repository actions, routed to the app via `dormant://` URLs (works with the window
  closed).
- Clean: preview of regenerable development state with per-path sizes and total reclaim, then
  confirmed removal — driven by an ecosystem-scoped classification rule table; anything not
  confidently classified is never removed.
- Archive: uncommitted-changes warning with counts, regenerable clean, verified gzip tarball plus
  `manifest.json` in `~/.dormant/store/`, working copy removed only after verification.
- Restore: extraction to the original or a chosen path, checksum verification against the
  manifest, then detected dependency install commands shown and confirmed before running.
- SQLite project registry (`~/.dormant/registry.sqlite`) and project scanning of chosen roots.
- Project Info view (local vs core vs regenerable sizes, git state, remote, last commit) and a
  configured editor command for Open (falls back to opening the folder).
- Repository scaffold from the `template-app-plus-site` template (docs-first skeleton; stack
  chosen at bootstrap).
- Promo site (Eleventy, `site/`) explaining the product and pointing at the download.
- Homebrew tap install (`PrakashSewani/homebrew-tap`): `brew tap PrakashSewani/tap && brew
  install --cask dormant` (D-010); distribution stays signing-free per D-001.

### Changed

- Release flow: release PRs from `dev` to `main` with exactly one `release:patch`,
  `release:minor`, or `release:major` label drive the version bump, `v<version>` tag, and GitHub
  release; unlabeled merges publish nothing.
