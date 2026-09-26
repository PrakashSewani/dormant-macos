# Architecture

Settled with D-001 (2026-09-26). Docs are the source of truth: code follows this file.

## Shape

One repository: the product and its promo site side by side.

- `Sources/`, `Tests/` — the product (Swift).
- `site/` — static promo site (phase 3). Deploys independently, imports no product code. Nothing
  is shared between product and site today; shared brand constants only earn their place if both
  sides actually need them.
- `project.yml` — XcodeGen manifest (committed). `Dormant.xcodeproj` is generated and never
  committed.
- `Scripts/check.sh` — the check command, the definition of done.

## Components

| Piece | Where | Responsibility |
|---|---|---|
| `DormantCore` | `Sources/DormantCore/` — static library, macOS 14+ | All logic: project detection and classification, size accounting, git inspection, SQLite registry, archive/restore engine, dependency-command detection. No UI. Fully unit-testable. |
| `DormantApp` | `Sources/DormantApp/` — macOS app (accessory / `LSUIElement`, menu bar) | Menu bar item (`MenuBarExtra`), main window (project list, Project Info, settings), preview/confirm dialogs, executes the real operations. Handles `dormant://` URLs. |
| `DormantFinder` | `Sources/DormantFinder/` — Finder Sync appex | Inline "Dormant ▸" context submenu on project folders. Forwards every action to the app via `dormant://`. Never performs destructive work itself. |
| `site/` | `site/` — static HTML/CSS | The promo site (phase 3). |
| (shared) | — | Nothing today. Product and site share no code. |

- Bundle IDs: `com.dormant.Dormant` (app), `com.dormant.Dormant.Finder` (appex). The app product is
  `Dormant.app` (`PRODUCT_NAME: Dormant` on the `DormantApp` target).
- Version source of truth: `MARKETING_VERSION` in `project.yml` (starts at 0.1.0).
- Signing: ad-hoc (`CODE_SIGN_IDENTITY=-`), no App Sandbox (local-only tool that must operate on
  arbitrary folders), no certificates/notarization — explicitly out of scope (D-001).

## Data flow

Data lives on the user's machine only; nothing leaves it.

- `~/.dormant/registry.sqlite` — the registry (system libsqlite3). Tables (finalized in phase 2):
  `projects` (id, name, path, ecosystem, state `active|dormant`, git remote, timestamps) and
  `archives` (id, project_id, store path, created_at, size, manifest path).
- `~/.dormant/store/<project-id>/core.tar.gz` + `manifest.json` — the archive of core files
  (file list, sizes, checksums, git HEAD, original path). gzip tarball via `/usr/bin/tar`.
- No copies of user source code anywhere except inside its own archive.

Flow: right-click in Finder → `Dormant ▸` menu (appex) → `dormant://<action>?path=<url-encoded>`
(actions: `open`, `clean`, `archive`, `restore`, `project-info`, `open-repository`) →
app foregrounds → preview/confirm dialog → `DormantCore` operation → registry update → result.

URL contract: `path` carries the selected item's file URL (`absoluteString`, percent-encoded).
URL handling must live at app level so it works with the main window closed (phase 2).

- **Clean:** classify files → preview (per-directory names + sizes + total reclaim) → confirm →
  remove regenerable paths only.
- **Archive:** git state check (warn with modified/untracked counts when dirty) → clean
  regenerable → tar core files → verify archive → remove working copy → state `dormant`.
- **Restore:** decompress to the original path (or user-chosen) → state `active` → detect
  ecosystem install commands → show exactly what will run → confirm → run.
- **Scan:** enumerate the user-chosen root(s) for projects (manifests / `.git`) and upsert the
  registry.

## Boundaries and invariants

The safety core — classification (`Sources/DormantCore/Classification.swift`, phase 2):

- Known ecosystem manifests map to regenerable patterns (e.g. `package.json` → `node_modules`,
  `.next`, `dist`; `pyproject.toml`/`requirements.txt` → `.venv`, `__pycache__`; `Cargo.toml` →
  `target`; `*.csproj`/`*.sln` → `bin`, `obj`; …).
- Unambiguous generic cache/build directories are handled only when they match a detected
  ecosystem.
- **Invariant (product.md safety rule 4): anything not confidently classified is never removed.**
  Deletions are always previewed with sizes and explicitly confirmed.

Other rules code must not break:

- Archiving never deletes a git repository; core files (source, `.git`, manifests, lockfiles,
  docs, configs, tests, assets, scripts) are never classified as regenerable.
- Uncommitted work is never silently discarded: Archive warns with counts first.
- All destructive operations route through the app's preview/confirm UI; the Finder extension
  only emits `dormant://` URLs.
- Local-first: no network calls, no accounts, no telemetry. Git remotes are only ever opened in
  the browser.

## Scaffold spec (phase 1)

`project.yml` defines four targets — `DormantCore` (static library), `DormantCoreTests`
(Swift Testing), `DormantApp` (application, embeds the appex), `DormantFinder` (Finder Sync
appex) — and a `Dormant` scheme that builds app + extension and runs the tests.

`Scripts/check.sh` (definition of done; CI runs exactly it):

1. `xcrun swift-format lint --recursive Sources Tests` (the bare `swift-format` is not on PATH)
2. `xcodegen generate`
3. `xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' build`
4. `xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' test`

CI (`.github/workflows/ci.yml`): on push/PR → `macos-26` runner → `actions/checkout@v7.0.1` →
`brew install xcodegen` → `Scripts/check.sh`.

Release (`.github/workflows/release.yml`): on tag `v*` → Release build → zip the `.app` →
`actions/upload-artifact@v7.0.1`. Publishing stays a deliberate manual step (ship-release skill).

Phase 1 code is deliberately minimal: everything compiles, the app launches with a menu bar item
and a placeholder window, the extension shows the submenu and routes `dormant://`, and
`DormantCore` carries the module skeleton with starter tests. Real behavior is phase 2.
