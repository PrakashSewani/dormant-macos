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

- **Phase:** 4 — launch. Phase 3 (promo site) is implemented, checked and green.
- **Done this session (phase 3):** site stack chosen with the human and recorded first — **D-009**
  (Eleventy 3.1.6, resolved live via `npm view`, Nunjucks → static `site/_site/`, zero client JS,
  lockfile committed); `site/` scaffolded (`package.json`, `eleventy.config.js`, `src/index.njk`,
  `src/_includes/base.njk`, `src/styles.css`); the one-page promo built to `docs/product.md`
  (the promise, a workspace size-receipt proof object, Clean/Archive/Restore with their safety
  notes, the install-command preview, the "rules Dormant will not break", download CTA to GitHub
  Releases); design pass in a storage-ledger direction (warm paper, serif display, mono data,
  hibernate/wake color roles) verified in a real browser at 1280×800 and 390×844, with the accent
  darkened from 4.3:1 to 5.3:1 contrast after the check; `Scripts/check.sh` gained step 5 (the
  site build) and CI runs exactly it, so no workflow change was needed; docs updated
  (`architecture.md` shape/components/check spec, `development.md` prerequisites/setup/commands/
  troubleshooting). Gotcha handled and documented: this machine's npm omits dev dependencies
  (`NODE_ENV=production`, `omit=dev`), so site installs use `npm ci --include=dev`.
- **Verified:** `Scripts/check.sh` end to end on the final tree — lint clean, build OK, **89 tests
  / 12 suites pass**, and `npm ci --include=dev && npm run build` writes `site/_site/index.html`
  and `styles.css`. Design verified from full-page screenshots at 1280×800 and 390×844 (hero wrap
  fixed after the first look; layout stacks cleanly on mobile).
- **Landing:** this work is committed on `feature/phase-3-promo-site` and opened as a PR to `dev`
  (merge via PR per D-007).
- **Blocked by:** (1) the manual Finder round trip on a real project (enable the extension in
  System Settings → Extensions, relaunch Finder; see `docs/development.md` troubleshooting);
  (2) human-only GitHub settings for D-007: create the `release:patch` / `release:minor` /
  `release:major` labels and make `dev` the default branch with required-PR protection.
- **Done this session (phase 3 polish + distribution plan):** footer styling fixed (it had been
  left unstyled and broke out of the content column; reproduced and verified in a Brave session
  via agent-browser CDP, hairline alignment corrected after a first pass); **D-010** recorded —
  distribution via our own Homebrew tap `PrakashSewani/homebrew-tap` with **no Apple Developer
  Program** (the human rejected the paid route); `homebrew/cask` submission explicitly deferred
  (Gatekeeper + notability bars, revisit only as its own decision); `ship-release` gained the tap
  publish procedure with the cask template (safe `zap`: never `~/.dormant`) and the GitHub Pages
  site-deploy procedure; README + promo site now carry the install command and the first-launch
  Gatekeeper note; the tap repo `PrakashSewani/homebrew-tap` was created.
- **Next action (new session):** merge the phase 3 PR into `dev`, then phase 4: the release PR
  from `dev` to `main` with one `release:*` label (ship-release skill) → run the tap publish
  procedure → manual site deploy when the human asks.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
