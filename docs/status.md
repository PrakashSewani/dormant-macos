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

- **Phase:** 4 — launch; the pre-release UI/distribution batch is complete on
  `feature/ui-glass-batch` (PR → `dev`).
- **Done this session:** (0) PR #7 + D-014 merged into `dev`; pulled. (1) **App cleanup**: exactly
  one `Dormant.app`, the fresh Release build at `/Applications/Dormant.app`; all build-artifact
  copies deleted (`~/.dormant` untouched). (2) **D-018–D-024 recorded and implemented** on
  `feature/ui-glass-batch`: Liquid Glass on a macOS 26 floor (target 26.0, UIConstants button min
  sizing, SF Symbols everywhere, brand-mark menu-bar icon `Mark.imageset`), **Git Clone into
  Folder** (D-020), **search + Stale badges** (D-021), **savings summary + Clean All…** (D-022),
  **auto-archive suggestions** (D-023), **menu-bar quick actions** (D-024), **DMG distribution**
  (D-019: `Scripts/make-dmg.sh`, release.yml ships `Dormant-v<version>.dmg`, cask template →
  `.dmg` + `>= :tahoe`). Site copy and CHANGELOG cover the batch.
- **Verified:** `Scripts/check.sh` end to end — lint clean, generate + build OK, **123 tests / 18
  suites pass** (19 new: CloneEngine, Staleness, Savings, IdleSuggestions), site builds (8 assets).
  DMG smoke: Release build → `Scripts/make-dmg.sh` → `build/Dormant-v0.1.0.dmg` with the
  drag-to-Applications window (create-dmg 1.3.0). Fresh Release app relaunched from
  `/Applications` for the hands-on pass.
- **Blocked by:** (1) the human's hands-on pass of the new UI/features (Finder: Git Clone round
  trip; app: glass look, button sizing, icons, search/stale, Clean All, idle banner, menu-bar
  actions); (2) human-only GitHub settings for D-007: the `release:patch` / `release:minor` /
  `release:major` labels (default branch is `dev`; PR protection unknown).
- **Next action (new session):** merge the batch PR after the human's pass, then the release PR
  `dev` → `main` with one `release:*` label (ship-release skill — DMG path) → tap publish
  (`Casks/dormant.rb` first creation from the template) → manual site deploy when the human asks
  → flip the site from "coming soon" to real download links and enable the brew command copy.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
