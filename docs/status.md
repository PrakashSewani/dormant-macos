# Status

Persistent project tracker and handoff. The agent updates this as work lands — see `AGENTS.md`,
rule 4. Keep exactly one phase `in progress`.

## Phase tracker

| Phase | Scope | Status |
|---|---|---|
| 0 | Requirements + stack selection: fill `docs/product.md`, choose the stack, record D-001 | complete |
| 1 | Scaffold: structure, checks, CI, release path — recorded in `docs/architecture.md` / `development.md` | complete |
| 2 | Product: the core workflow, end to end | in progress |
| 3 | Promo site: the site that explains it and sends people to it | not started |
| 4 | Launch: first release tagged, site deployed | not started |

## Current handoff

- **Phase:** 2 — product core workflow; scaffold complete and independently verified.
- **Done this session (phases 0–1):** brief in `docs/product.md`; D-001 (Swift 6.4 / Xcode 27.0,
  XcodeGen 2.46.0, zero third-party deps); scaffold by `implementer` (project.yml, four targets,
  menu bar app, Finder Sync extension routing `dormant://`, DormantCore skeleton with classifier
  and tests, `Scripts/check.sh`, CI + release workflows, `site/index.html`); integration fixes
  (`xcrun swift-format`, check.sh self-locates Xcode, app product `Dormant.app`);
  `docs/development.md` and the ship-release procedure filled with commands actually run.
- **Verified:** `verifier` subagent verdict **SHIPPABLE** (all 9 criteria PASS with evidence):
  it re-ran `Scripts/check.sh` itself (BUILD/TEST SUCCEEDED, 2 tests / 13 cases), confirmed
  targets/bundle IDs/signing/no-sandbox against the docs, Finder Sync Info.plist + six menu
  actions + `dormant://` slugs, release artifact path with embedded appex, zero dependencies,
  and no destructive/network code. Locally also: Release zip smoke (16 files),
  `codesign --verify --deep --strict` OK, app launch/quit OK, site serves (HTTP 200).
- **Blocked by:** nothing. One manual check for the human: the "Dormant ▸" Finder context menu
  (enable the extension in System Settings → Extensions, relaunch Finder; see
  `docs/development.md` troubleshooting).
- **Next action (new session):** re-validate phases 0–1 on `dev` (run `Scripts/check.sh` and the
  `verifier` against the docs), then build phase 2 — the real workflow in DormantCore + UI:
  classification rule table (`Classification.swift`, regenerable patterns per ecosystem), SQLite
  registry, scan, then Clean → Archive → Restore with preview/confirm dialogs; pin app-level
  `dormant://` handling (works with window closed; `path` = file URL `absoluteString`, per
  `docs/architecture.md` URL contract). Work happens on `dev` and merges via PR — branching model
  in `docs/decisions.md` D-002.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
