# Dormant

A macOS developer utility for managing the lifecycle of project workspaces: clean, archive, and
restore local projects without losing your repositories.

**The repository is permanent, the local development environment is disposable.** Clean what can
be regenerated. Keep what matters. Put unused projects to sleep. Wake them when you need them.

## What it does

From the Finder "Dormant ▸" context menu on a project folder (and the menu bar app):

- **Open** — launch the project in your configured editor command (falls back to opening the
  folder).
- **Clean** — remove regenerable development state (`node_modules`, `target`, `.venv`, build
  output, caches) after a preview with per-path sizes. Never removes anything it cannot
  confidently classify as regenerable.
- **Archive** — warn about uncommitted changes, clean regenerable state, compress everything that
  remains into `~/.dormant/store/`, and remove the working copy only after the archive is
  verified. The repository itself is never deleted.
- **Restore** — decompress to the original path (or one you choose), verify every file against
  the manifest checksums, then show the detected dependency install commands and run them only
  after you confirm.
- **Project Info** — why a project is consuming disk: sizes, git state, remote, last commit.
- **Open Repository** — open the project's git remote in the browser.

Local-first: no accounts, no telemetry, nothing leaves your Mac. The full brief is in
[`docs/product.md`](docs/product.md).

## Status

Phase 2 (the core workflow) is implemented and tested; nothing is released yet. The current
phase and handoff live in [`docs/status.md`](docs/status.md).

## Development

Swift / Xcode — prerequisites and exact commands in
[`docs/development.md`](docs/development.md). The gate is `Scripts/check.sh` (lint → generate →
build → test); it must pass before anything is "done".

## Releases

Release PRs from `dev` to `main` carry exactly one `release:patch`, `release:minor`, or
`release:major` label; the release workflow bumps the version, tags `v<version>`, and publishes
the GitHub release. Product and site deployments stay manual. See
[`docs/development.md`](docs/development.md) and
[`.commandcode/skills/ship-release/SKILL.md`](.commandcode/skills/ship-release/SKILL.md).

## Repository docs

- [`docs/product.md`](docs/product.md) — the brief and the safety rules
- [`docs/architecture.md`](docs/architecture.md) — components, data flow, safety invariants
- [`docs/decisions.md`](docs/decisions.md) — settled decisions (stack, release flow, safety)
- [`docs/status.md`](docs/status.md) — phase tracker and handoff
- [`docs/development.md`](docs/development.md) — setup and commands

Scaffolded from the `template-app-plus-site` repository template.

## License

[MIT](./LICENSE)
