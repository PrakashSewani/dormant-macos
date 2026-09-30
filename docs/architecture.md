# Architecture

Settled with D-001 (2026-09-26). Docs are the source of truth: code follows this file.

## Shape

One repository: the product and its promo site side by side.

- `Sources/`, `Tests/` — the product (Swift).
- `site/` — the promo site (Eleventy 3.1.6, D-009): Nunjucks templates in `site/src/`, hand-written
  CSS, no client JS, static output to `site/_site/` (gitignored). Deploys independently, imports
  no product code. Nothing is shared between product and site today; shared brand constants only
  earn their place if both sides actually need them.
- `project.yml` — XcodeGen manifest (committed). `Dormant.xcodeproj` is generated and never
  committed.
- `Scripts/check.sh` — the check command, the definition of done.

## Components

| Piece | Where | Responsibility |
|---|---|---|
| `DormantCore` | `Sources/DormantCore/` — static library, macOS 14+ | All logic: project detection and classification, size accounting, git inspection, SQLite registry, archive/restore engine, dependency-command detection. No UI. Fully unit-testable. |
| `DormantApp` | `Sources/DormantApp/` — macOS app (accessory / `LSUIElement`, menu bar) | Menu bar item (`MenuBarExtra`), main window (project list, Project Info), preview/confirm dialogs, executes the real operations. Handles `dormant://` URLs. |
| `DormantFinder` | `Sources/DormantFinder/` — Finder Sync appex | Inline "Dormant ▸" context submenu on project folders: Clean, Archive, Restore, Import Folder in Dormant; empty-space clicks get Open Directory in Dormant (D-017). Forwards every action to the app via `dormant://`. Never performs destructive work itself. |
| `site/` | `site/` — Eleventy (Nunjucks → static HTML) | The promo site: the product promise and the download link. |
| (shared) | — | Nothing today. Product and site share no code. |

- Bundle IDs: `com.dormant.Dormant` (app), `com.dormant.Dormant.Finder` (appex). The app product is
  `Dormant.app` (`PRODUCT_NAME: Dormant` on the `DormantApp` target).
- Version source of truth: `MARKETING_VERSION` in `project.yml` (starts at 0.1.0).
- Signing: ad-hoc (`CODE_SIGN_IDENTITY=-`), no certificates/notarization (D-001). Sandbox split
  (D-011): `DormantFinder` carries App Sandbox
  (`Sources/DormantFinder/DormantFinder.entitlements`) because macOS loads no non-sandboxed app
  plugin; `DormantApp` / `DormantCore` have none (must operate on arbitrary folders).

## Data flow

Data lives on the user's machine only; nothing leaves it.

**Registry** — `~/.dormant/registry.sqlite` (system libsqlite3; PRAGMA `user_version = 2`,
`journal_mode=WAL`, `foreign_keys=ON`). Three tables (`last_scanned_at` is an addition to the
earlier sketch of `projects`; `directories` is the schema v2 addition, D-017):

```sql
CREATE TABLE projects (
  id          TEXT    PRIMARY KEY,          -- UUID uuidString
  name        TEXT    NOT NULL,
  path        TEXT    NOT NULL UNIQUE,      -- standardized absolute path
  ecosystem   TEXT    NOT NULL,             -- node|python|rust|dotnet|go|unknown
  state       TEXT    NOT NULL CHECK (state IN ('active','dormant')),
  git_remote  TEXT,
  created_at  TEXT    NOT NULL,             -- ISO-8601
  updated_at  TEXT    NOT NULL,
  last_scanned_at TEXT                     -- phase 2 addition
);
CREATE TABLE archives (
  id           TEXT    PRIMARY KEY,
  project_id   TEXT    NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  store_path   TEXT    NOT NULL,            -- absolute path to core.tar.gz (not the dir)
  created_at   TEXT    NOT NULL,
  size         INTEGER NOT NULL,            -- tarball bytes
  manifest_path TEXT   NOT NULL             -- absolute path to manifest.json
);
CREATE UNIQUE INDEX archives_one_per_project ON archives(project_id);
CREATE TABLE directories (
  id          TEXT    PRIMARY KEY,          -- UUID uuidString
  name        TEXT    NOT NULL,
  path        TEXT    NOT NULL UNIQUE,      -- standardized absolute path
  created_at  TEXT    NOT NULL,             -- ISO-8601
  last_scanned_at TEXT                     -- schema v2 addition (D-017)
);
```

All timestamps are ISO-8601 text. One archive per project (`UNIQUE(project_id)`); re-archiving
replaces the row and the store directory. `store_path` is the absolute path to the tarball itself;
`manifest_path` points at its sibling `manifest.json`. A dormant project keeps its `projects` row
(`path` = the original location, which may not exist on disk) so archive-only projects stay
restorable. `directories` holds the folders imported into Dormant (Finder import/open, app
Scan…); a project groups under its deepest containing directory by path prefix — never by
foreign key — and each directory row reports the whole folder's on-disk size (D-017).

**Archive store** — `~/.dormant/store/<project-id>/core.tar.gz` + `manifest.json`, gzip tarball via
`/usr/bin/tar`. Per D-003 the tarball contains **everything left after the clean step** (core +
unclassified files); the manifest labels each file's kind (`core | unclassified`).

No copies of user source code anywhere except inside its own archive — and after a
checksum-verified restore, not even there (the store directory is deleted; D-004).

Flow: right-click in Finder → `Dormant ▸` menu (appex) → `dormant://<action>?path=<url-encoded>`
(actions: `open`, `clean`, `archive`, `restore`, `project-info`, `open-repository`) →
app foregrounds → preview/confirm dialog → `DormantCore` operation → registry update → result.

URL contract: `path` carries the selected item's file URL (`absoluteString`, percent-encoded).
URL handling is app-level (`application(_:open:)`) so it works with the main window closed.
Every action first registers or refreshes its project in the registry
(`Scanner.register(projectAt:)`, state-preserving), so the app's list always reflects what the
user touches (D-012).
`restore` for an archive-only project cannot come from Finder (there is no folder to
right-click); it is triggered from the app's project list.

## Flows

Plan/execute split: each flow is a pure planning step returning a value object (`CleanPlan`,
`ArchivePlan`, `RestorePlan`) plus an execute step consuming exactly that plan. The UI renders
plans and confirms; Core executes. `execute(plan:)` is the only removal entry point.

- **Scan:** DFS from the user-chosen root(s), bounded depth (default 3), skipping hidden dirs and
  the static regenerable name list (never walked into), plus `~/.dormant/store` if inside a root.
  A project is a directory containing `.git` or ≥1 known manifest; topmost wins (monorepo members
  are not projects). Upsert by standardized path: new row → insert (UUID, `active`); active row →
  update name/ecosystem/git remote/timestamps but never `state`; dormant row + live dir → `active`
  again, reported in `reappeared`. Missing active paths are reported in `missing`, never
  auto-deleted. (`ScanReport { added, updated, missing, reappeared }`.)
- **Clean:** classify → `CleanPlan` (per-path name, size, matched rule) → preview with names,
  sizes, total reclaim (and the permanent, nothing-archived note, D-012) → confirm → remove
  regenerable paths only. Unlink, not Trash — regenerable by definition. Per-path failures are
  collected, not fatal.
- **Archive:** git check (see Git inspection; dirty **or unknown** → warn with modified/untracked
  counts first — uncommitted files are preserved inside the archive — and proceed only on explicit
  confirm) → clean regenerable (record reclaimed bytes) → manifest data: walk the entire remaining
  tree (core + unclassified) → `tar -czf core.tar.gz` into `~/.dormant/store/<project-id>/` →
  **verify before removing anything**: `tar -tzf core.tar.gz` entry set (normalized) must equal the
  expected entry set — every file, directory, and symlink remaining after the clean — and exit 0; on
  mismatch the store dir is deleted, the working copy is
  untouched, error `verificationFailed` → write `manifest.json` → one registry transaction
  (`state=dormant` + archive row) → remove the working copy. If that removal fails: "archive
  verified and stored, but the working copy could not be removed" (state stays `dormant`).
- **Restore:** destination = original path (default) or user-chosen; **refuse if it exists
  non-empty** (never merge/overwrite) → extract `core.tar.gz` → verify extraction against the
  manifest (exists, size, SHA-256); on mismatch leave the extracted tree for inspection and keep
  the archive → registry transaction (`state=active`, archive row removed) and **delete the store
  directory** (D-004) → detect install commands → show exactly what will run → run only after
  confirm.

`manifest.json` (v1):

```json
{
  "manifestVersion": 1,
  "project": { "id": "<uuid>", "name": "...", "originalPath": "/Users/x/Projects/foo",
               "ecosystems": ["node"], "archivedAt": "2026-…Z" },
  "git": { "isRepo": true, "head": "<sha>", "branch": "dev", "remote": "git@…",
           "dirty": true, "modifiedCount": 3, "untrackedCount": 1 },
  "tarball": { "name": "core.tar.gz", "size": 123456, "sha256": "…", "fileCount": 421,
               "uncompressedSize": 789012 },
  "files": [ { "path": "Package.swift", "size": 812, "sha256": "…", "kind": "core" } ]
}
```

The `files` list covers regular files (the checksum-verified restore set); directories and symlinks
are held to the entry-set verification at archive time and round-trip untouched.

## Classification — the safety core

`Sources/DormantCore/Classification.swift`, `ClassificationRules.swift`, `SizeAccounting.swift`.
Patterns carry one of two scopes: `anywhereInProject` (any depth) and `manifestSibling` (only
directly beside the manifest that licenses the rule).

| Manifest(s) | Ecosystem | `anywhereInProject` | `manifestSibling` |
|---|---|---|---|
| `package.json` | node | `node_modules` | `.next`, `.nuxt`, `.turbo`, `.svelte-kit`, `.parcel-cache`, `dist`, `build`, `coverage`, `.cache` |
| `pyproject.toml`, `requirements.txt` | python | `__pycache__`, `.venv`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.tox` | `*.egg-info` (suffix), `build`, `dist`, `.coverage` |
| `Cargo.toml` | rust | — | `target` |
| `*.csproj`, `*.sln` | dotnet | — | `bin`, `obj` (dirs next to a `*.csproj`; a lone `*.sln` gives no sibling patterns) |
| `go.mod` | go | — | — (no project-local regenerable state; `vendor` is sometimes committed) |

- Ambiguous basenames (`dist`, `build`, `bin`, `obj`, `target`) match only in manifest-sibling
  scope (D-005): a hand-made `docs/build/` or `assets/target/` is never regenerable. Generic cache
  names are matched only through a rule for a detected ecosystem — never bare.
- `venv` (non-dot) is root-only; `.venv` may be anywhere.
- Ecosystem set = the five above; `Gemfile`/`setup.py`/`pom.xml` stay `unknown`. Adding an
  ecosystem is a data change to the rule table.
- Multi-ecosystem trees classify as the union of every rule whose manifests exist in the tree. The
  registry stores one primary ecosystem (root-level manifest precedence: `Cargo.toml` >
  `package.json` > `pyproject.toml`/`requirements.txt` > `*.csproj`/`*.sln` > `go.mod` > first
  match).
- Manifest discovery walks the tree skipping hidden dirs, `.git`, and the static union of all
  regenerable names — purely a discovery performance gate, never a deletion gate.

**Invariant (product.md safety rule 4): anything not confidently classified is never removed.**
Enforced structurally, not by convention:

1. `RegenerablePath` can only be minted by the classifier (initializer internal to the
   classification file); removal engines accept only `[RegenerablePath]`.
2. `execute` re-validates every path before removal: inside the standardized project root after
   symlink resolution, still matching its recorded rule (basename + scope), a directory (or
   suffix-matched file). A symlink root is removed as a link — never walked through.
3. Classification and size walks never follow symlinks.
4. Everything outside `regenerable` is core or unclassified: Clean never sees it, Archive tars it
   (D-003), Restore never filters it.

Deletions are always previewed with sizes and explicitly confirmed. `SizeAccounting` sums
regular-file bytes per top-level regenerable path (no symlink following) for previews and Project
Info.

## Git inspection

Shells out to `/usr/bin/git` (D-001), read-only only, `--no-optional-locks`, `-C <root>`:

- `rev-parse --is-inside-work-tree` (is a repo); `status --porcelain=v1 -uall` (`??` lines =
  untracked, every other non-empty line = modified, staged+unstaged combined); `rev-parse HEAD`;
  `rev-parse --abbrev-ref HEAD`; `remote get-url origin` (fallback: first remote from
  `remote -v`; none → nil → Open Repository disabled).
- Never run mutating git commands. Git missing or broken → state unknown → **warn as if dirty**.

## Restore install commands

Lockfile first, manifest fallback. `InstallCommand { executable, args, cwd, display, reason }`,
run in the project root, sequentially:

| Signal | Commands (exact argv) |
|---|---|
| `pnpm-lock.yaml` | `pnpm install` |
| `yarn.lock` | `yarn install` |
| `bun.lockb` / `bun.lock` | `bun install` |
| `package-lock.json` or bare `package.json` | `npm install` |
| `uv.lock` | `uv sync` |
| `poetry.lock` | `poetry install` |
| `requirements.txt` | *(if `.venv` absent: `python3 -m venv .venv`)* then `.venv/bin/python -m pip install -r requirements.txt` |
| `pyproject.toml` only | *(if `.venv` absent: `python3 -m venv .venv`)* then `.venv/bin/python -m pip install -e .` |
| `Cargo.toml` | `cargo build` |
| `*.sln` / `*.csproj` | `dotnet restore` |
| `go.mod` | `go mod download` |

- Multi-ecosystem projects concatenate commands in table order; nothing detected → "no dependency
  commands detected".
- The dialog lists each `display` verbatim (monospace) with its reason and cwd; confirm runs all
  (all-or-nothing in phase 2). Execution is sequential and stops at the first non-zero exit
  (report which command failed and which were not run), streamed output, cancellation between
  commands. Executables resolve through `ToolLocator`'s hardcoded search list (D-015): tool-manager
  dirs (`~/.nvm/versions/node/*/bin`, newest node first, `~/.volta/bin`, `~/.bun/bin`,
  `~/.cargo/bin`, `~/.asdf/shims`, `~/.local/bin`, `~/go/bin`), Homebrew (`/opt/homebrew/bin`,
  `/opt/homebrew/sbin`), `/usr/local/bin`, `/usr/local/sbin`, `/usr/local/share/dotnet`, then the
  system dirs. A name containing `/` (`.venv/bin/python`) resolves against the project root. A tool
  not found fails with exit status 127 and a message listing the searched directories — no
  fallback, no user configuration (supersedes the old `/usr/bin/env` + inherited `PATH` lookup).

## Shared plumbing

`ProcessRunner` (Process wrapper: argv, cwd, env, captured stdout/stderr, exit code,
cancellation), `ToolLocator` (hardcoded lookup of external executables — D-015), `Checksums`
(SHA-256 via system CryptoKit), `DormantError` taxonomy (`notAProject`,
`gitUnavailable`, `archiveExists`, `targetNotEmpty`, `tarFailed(stderr)`,
`verificationFailed(details)`, `registryFailure`, `installCommandFailed(cmd, status, stderr)`).

## Boundaries and invariants

Other rules code must not break:

- Archiving never deletes a git repository; core files (source, `.git`, manifests, lockfiles,
  docs, configs, tests, assets, scripts) are never classified as regenerable.
- Uncommitted work is never silently discarded: Archive warns with counts first.
- All destructive operations route through the app's preview/confirm UI; the Finder extension
  only emits `dormant://` URLs.
- Local-first: no network calls, no accounts, no telemetry. Git remotes are only ever opened in
  the browser.

## Branch and release flow

Imported from the template 2026-09-26 (`docs/decisions.md` D-007). It supersedes the
tag-triggered release description in the scaffold spec below; `.github/workflows/release.yml`
implements this flow (reworked 2026-09-26: a labeled release-PR merge bumps `MARKETING_VERSION`,
promotes the `[Unreleased]` changelog section, tags, and publishes; an unlabeled merge exits
without publishing).

- `dev` is the default branch and the integration target. Changes stay on a feature branch and
  reach `dev` through a pull request; never commit or push directly to `dev` or `main`.
- A release is proposed by a pull request from `dev` to `main`. CI validates changes on PRs and
  development branches, but release-related workflows trigger only after changes reach `main`.
- A release PR carries exactly one `release:patch`, `release:minor`, or `release:major` label.
  On merge, release automation bumps `MARKETING_VERSION` in `project.yml`, updates
  `CHANGELOG.md`, creates the matching `v<version>` tag, and publishes a GitHub release with the
  zipped `Dormant.app`. Without a release label, no release is published.
- `dev` represents ongoing unreleased work and can match `main` just after a release. Deployment
  of the product or promo site remains a deliberate manual action.
- Required GitHub repository settings (human-only): default branch `dev`, required-PR
  protections for `dev` and `main`, and the three `release:*` labels.

## Scaffold spec (phase 1)

`project.yml` defines four targets — `DormantCore` (static library), `DormantCoreTests`
(Swift Testing), `DormantApp` (application, embeds the appex), `DormantFinder` (Finder Sync
appex) — and a `Dormant` scheme that builds app + extension and runs the tests.

`Scripts/check.sh` (definition of done; CI runs exactly it):

1. `xcrun swift-format lint --recursive Sources Tests` (the bare `swift-format` is not on PATH)
2. `xcodegen generate`
3. `xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' build`
4. `xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' test`
5. `npm ci --include=dev && npm run build` in `site/` (the Eleventy promo-site build, D-009)

CI (`.github/workflows/ci.yml`): on push/PR → `macos-26` runner → `actions/checkout@v7.0.1` →
`brew install xcodegen` → `Scripts/check.sh`.

Release (`.github/workflows/release.yml`): on tag `v*` → Release build → zip the `.app` →
`actions/upload-artifact@v7.0.1`. Publishing stays a deliberate manual step (ship-release skill).

Phase 1 landed this scaffold as deliberately minimal code (menu bar item with a placeholder
window, submenu routing, a module skeleton). Phase 2 replaced the placeholders with the real
workflow described above: the app hosts the project list, the preview/confirm dialogs, and Project
Info; the extension routes the Finder actions through `dormant://` (five as of D-017); and `DormantCore`
holds the full engine behind the test suite run by `Scripts/check.sh`. Phase 3 replaced the
placeholder `site/index.html` with the Eleventy promo site (D-009).
