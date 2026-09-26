# Status

Persistent project tracker and handoff. The agent updates this as work lands — see `AGENTS.md`,
rule 4. Keep exactly one phase `in progress`.

## Phase tracker

| Phase | Scope | Status |
|---|---|---|
| 0 | Requirements + stack selection: fill `docs/product.md`, choose the stack, record D-001 | complete |
| 1 | Scaffold: structure, checks, CI, release path — recorded in `docs/architecture.md` / `development.md` | complete |
| 2 | Product: the core workflow, end to end | complete |
| 3 | Promo site: the site that explains it and sends people to it | in progress |
| 4 | Launch: first release tagged, site deployed | not started |

## Current handoff

- **Phase:** 3 — promo site. Phase 2 (product core workflow) is implemented and green.
- **Done this session (phase 2):** phases 0–1 re-validated (`Scripts/check.sh` green); design
  settled with the human — D-003 (archive tarball = everything left after clean), D-004 (store
  deleted after a checksum-verified restore), D-005 (manifest-sibling scoping for ambiguous
  names), D-006 (Open = user-configured editor command, falling back to opening the folder) — all
  in `docs/decisions.md`; then implemented end to end: classification rule table +
  `SizeAccounting`, SQLite registry schema v1 (`SQLiteDB.swift`, `Registry.swift`), `GitInspector`
  / `ProcessRunner` / `Checksums` / `DormantError` / `DormantURL`, `Scanner`, `CleanEngine`
  (plan/execute with re-validation before every removal), `ArchiveEngine` + `manifest.json` v1
  (D-003; `tar -tzf` entry-set verification before the working copy is removed), `RestoreEngine`
  (checksum-verified extraction, D-004) + `InstallCommands`/`InstallRunner`, and the app:
  app-level `dormant://` handling via `application(_:open:)` (works with the window closed),
  `ActionPresenter` preview/confirm dialogs for all six actions, project list with
  Scan/Refresh/sizes/state badges, Project Info, and the editor-command setting (D-006). All code
  written directly and sequentially per the human's instruction (no subagents).
- **Done this session (template sync):** pulled `template-app-plus-site` `dev` and merged it:
  `AGENTS.md` now carries the senior-architect model (primary agent implements directly;
  subagents read-only discovery only) and the labeled release policy; `CONTRIBUTING.md`,
  `.github/PULL_REQUEST_TEMPLATE.md`, `project-bootstrap` updated from the template;
  `ship-release` rewritten to the labeled flow keeping the real commands; decisions **D-007**
  (labeled automated releases — supersedes D-002's manual tagging) and **D-008** (agent
  operating model) recorded; `architecture.md` gained "Branch and release flow";
  `development.md` releases section updated; template name fixed back to
  `template-app-plus-site` where the bootstrap rename had replaced it (README, CHANGELOG,
  skill metadata); and `.github/workflows/release.yml` reworked (human-approved) from the tag
  trigger to the D-007 labeled-merge flow — label parsing and the version/changelog bump were
  dry-run locally (0.1.0 → 0.2.0, `[Unreleased]` promoted to the version section, notes
  extracted); README rewritten as the product README and docs audited against the
  implementation.
- **Landing:** the session's work is committed on `feature/phase-2-core-workflow` and opened as a
  PR to `dev` (merge via PR per D-007).
- **Verified:** `Scripts/check.sh` end to end — lint clean, build OK, **89 tests / 12 suites
  pass**. Tests include the archive→restore round trip with real `tar`/`git`, dirty-git warning
  counts, tar-verification failure leaving the working copy intact with no registry row, tampered
  clean plans rejected before removal, checksum-mismatch restore keeping archive and extracted
  tree, the install-command detection table, and `dormant://` URL round-trips. App launch/quit
  smoke OK on the Debug build.
- **Blocked by:** (1) the manual Finder round trip on a real project (enable the extension in
  System Settings → Extensions, relaunch Finder; see `docs/development.md` troubleshooting);
  (2) human-only GitHub settings for D-007: create the `release:patch` / `release:minor` /
  `release:major` labels and make `dev` the default branch with required-PR protection.
- **Next action (new session):** phase 3 — the promo site in `site/` (currently a placeholder `index.html`):
  explain the product promise ("the repository is permanent, the local development
  environment is disposable") and point people at the download; it deploys independently of the
  product (see `docs/architecture.md`, repo shape). Then phase 4: the first release PR from
  `dev` to `main` (ship-release skill).

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
