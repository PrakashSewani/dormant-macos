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

- **Phase:** 4 — launch; **v0.2.0 is published** (2026-10-03: tag + GitHub release with
  `Dormant-v0.2.0.dmg`, Homebrew tap bumped and brew-verified, site download links live).
- **Done this session (2026-10-03):** D-026 Finder-extension auto-enablement (feature PR #16),
  then the v0.2.0 release: prep PR #17 (first back-merge of `main` into `dev`, CHANGELOG
  realigned, README/skill/development copy refreshed), release PR #18 (`release:minor` →
  workflow cut v0.2.0 with the D-026 note), tap commit `dormant 0.2.0` (version + sha256 +
  caveats/README), site PR #19 (DMG links → v0.2.0), and this back-merge PR.
- **Verified:** `Scripts/check.sh` green on the feature and both prep/site PRs; `check` CI green
  on #16–#19; release workflow green (1m29s) with release notes = the D-026 entry. DMG smoke:
  mount, app version 0.2.0, launch/quit OK. Tap: `brew upgrade --cask dormant` 0.1.0 → 0.2.0,
  uninstall leaves `~/.dormant` intact, reinstall 0.2.0. Live site serves v0.2.0 links (~50s
  after merge).
- **Blocked by:** human-only first launch of the 0.2.0 build — Gatekeeper "Open Anyway" (the new
  ad-hoc signature is quarantined again), then the "Dormant ▸" menu; the UI batch's hands-on
  pass also remains open.
- **Next action:** human smoke pass on 0.2.0 → mark Phase 4 complete.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
