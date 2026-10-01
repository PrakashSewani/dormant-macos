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

- **Phase:** 4 — launch; **v0.1.0 is published** (tag + GitHub release + Homebrew tap); the site
  goes live with the download links on the merge of this PR.
- **Done this session:** (0) Release labels `release:patch` / `release:minor` / `release:major`
  created on GitHub (D-007 unblocked). (1) Prep PR #9: `MARKETING_VERSION` 0.1.0 → 0.0.9 so the
  labeled bump lands the first release on 0.1.0. (2) Release PR #10 (`release:patch`) cut
  **v0.0.10** — patch increments the last segment, so 0.0.9 → 0.0.10; wrong per the human's
  explicit v0.1.0 decision, yanked on the spot (release + tag deleted, bump reverted on `main`
  via no-label PR #11 — nothing had consumed it). (3) **v0.1.0 cut** via `release:minor` (PR
  #13): `Release v0.1.0` commit on `main`, tag, GitHub release with `Dormant-v0.1.0.dmg`.
  (4) **Tap published**: `Casks/dormant.rb` created in `PrakashSewani/homebrew-tap` (`dormant
  0.1.0`), plus a fix to the deprecated `depends_on macos: ">= :tahoe"` syntax (`:tahoe`),
  template in ship-release updated to match. (5) **Brew verified** end to end. (6) **Site
  flipped** (this PR): real DMG download buttons (both CTA spots), brew command copy enabled
  (inline clipboard script), "coming soon" / "not published" copy gone; ship-release now records
  the per-release site DMG-link bump.
- **Verified:** `Scripts/check.sh` green — lint, generate + build, **123 tests / 18 suites
  pass**, site build (8 assets, 1 file). Release workflow green end to end twice (v0.0.10
  attempt and v0.1.0, 1m55s each). CI `check` green on PRs #9, #11, #12, #13.
  `brew fetch --cask` checksum OK (`e0c9051b…`) → install → uninstall → reinstall;
  `/Applications/Dormant.app` is v0.1.0 (brew-managed) and **uninstall leaves `~/.dormant`**
  (registry + store) untouched (D-010).
- **Blocked by:** human-only launch smoke: first launch of the brew-installed app (Gatekeeper →
  Privacy & Security → "Open Anyway") and enabling the Finder extension; the UI batch's hands-on
  pass also remains open (skipped by explicit launch instruction).
- **Next action:** human smoke pass → mark Phase 4 complete. Per release from now on: release PR
  (`release:*`) → tap `version`/`sha256` bump → site DMG-link bump (ship-release steps 5–6).

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
