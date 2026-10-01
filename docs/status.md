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

- **Phase:** 4 — launch; cutting the first release **v0.1.0**.
- **Done this session:** (0) Release labels `release:patch` / `release:minor` / `release:major`
  created on GitHub (D-007 unblocked). (1) Prep PR #9: `MARKETING_VERSION` 0.1.0 → 0.0.9 so the
  labeled bump lands the first release exactly on 0.1.0. (2) Release PR #10 merged with
  `release:patch` — by the bump arithmetic that cut **v0.0.10** (patch increments the last
  segment), wrong per the human's explicit v0.1.0 decision. Yanked on the spot: release and tag
  deleted, the `Release v0.0.10` commit reverted on `main` (PR #11, no release label = no
  publish). Nothing consumed v0.0.10 (tap and site were still untouched). (3) This update rides
  the redo: release PR `dev` → `main` with `release:minor` (0.0.9 → **0.1.0**).
- **Verified:** CI `check` green on PRs #9, #10, #11. The release workflow ran end to end on the
  v0.0.10 attempt (bump → changelog → tag → Release build + DMG → GitHub release, 1m55s) — the
  pipeline itself is proven.
- **Blocked by:** nothing.
- **Next action:** merge the `release:minor` release PR (v0.1.0) → publish `Casks/dormant.rb` to
  `PrakashSewani/homebrew-tap` (ship-release skill step 6) → flip the site copy from "coming
  soon" to the real download link + enable the brew command copy (branch/PR into `dev`,
  auto-deploys) → final status.md + `brew install --cask` smoke.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
