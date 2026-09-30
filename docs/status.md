# Status

Persistent project tracker and handoff. The agent updates this as work lands — see `AGENTS.md`,
rule 4. Keep exactly one phase `in progress`.

## Phase tracker

| Phase | Scope | Status |
|---|---|---|
| 0 | Requirements + stack selection: fill `docs/product.md`, choose the stack, record D-001 | complete |
| 1 | Scaffold: structure, checks, CI, release path — recorded in `docs/architecture.md` / `development.md` | complete |
| 2 | Product: the core workflow, end to end | complete |
| 3 | Promo site: the site that explains it and sends people to it | complete |
| 4 | Launch: first release tagged, site deployed | in progress |

## Current handoff

- **Phase:** 4 — launch.
- **Done this session:** (1) **D-015** — `ToolLocator`: every external tool (all package managers
  + `code`) resolves from a hardcoded ordered search of known install locations (nvm
  newest-node-first, volta, bun, cargo, asdf shims, `~/.local/bin`, `~/go/bin`, Homebrew,
  `/usr/local…`, system); missing tool = exit 127 with the searched list and the queue stops; no
  configuration, no fallbacks. Open is hardcoded `code .` (D-006 superseded, editor setting
  deleted). (2) **D-016** — Finder "Dormant ▸" hover submenu rebuilt with an explicit root item
  (Finder inserts menu items flat and ignores `NSMenu` titles). (3) **D-017** — directories are
  first-class: registry schema v2 (`directories` table, v1 upgrades in place);
  `Scanner.importDirectory` (import = upsert directory + scan); Finder menus scoped by click
  kind — folder items get Clean/Archive/Restore/Import Folder in Dormant, **empty space** gets
  **Open Directory in Dormant** (imports the folder, opens the app with it selected); the main
  window groups projects under their deepest containing directory (`DirectoryGrouping`) and
  shows each directory's **whole-folder on-disk size**. (4) Site copy covers the new features
  (directories section, Finder menus, toolchain-aware Restore). (5) Merged `origin/dev` — the
  D-014 icon work landed there via PR #6 (`3916497`) — into `feature/icon-cocoon`, resolving the
  decisions/status conflicts in favour of this session's text.
- **Verified:** `Scripts/check.sh` end to end — lint clean (pre-existing Dialogs.swift warnings
  only), generate + build OK, **104 tests / 14 suites pass** (14 new across ToolLocator,
  InstallCommands, Registry v2/migration, Scanner import, DirectoryGrouping, URL slugs), site
  builds (8 assets copied). Finder menus and the grouped list await the human's hands-on pass;
  app + Finder extension restarted from the fresh Debug build for that.
- **Landing:** PR #7 (`feature/icon-cocoon` → `dev`) is open and carries D-015–D-017, the site
  copy, and this merge. The D-014 icon work is already in `dev` (PR #6).
- **Blocked by:** (1) the human's Finder round trip: folder right-click → 4-item "Dormant ▸"
  (Clean, Archive, Restore, Import Folder in Dormant); empty-space right-click → Open Directory
  in Dormant → app opens with the directory selected and its whole-folder size shown;
  (2) human-only GitHub settings for D-007: the `release:patch` / `release:minor` /
  `release:major` labels and `dev` as default branch with required-PR protection.
- **Next action (new session):** merge PR #7 once the human approves, then take the Finder
  round-trip confirmation and the release PR from `dev` to `main` with one `release:*` label
  (ship-release skill) → tap publish procedure → manual site deploy when the human asks. When
  the first release ships, flip the site from "coming soon" to real download links and enable
  the brew command copy.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
