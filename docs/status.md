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

- **Phase:** 4 — launch. The icon work is on `feature/icon-cocoon` → PR → `dev` (this session).
- **Done this session:** (1) **D-014** — new mark, the **cocoon**: nine witty candidates (paused,
  folder with Z, standby glyph, tucked-in, vacuum bag, tin can, cocoon, hammock, seed) were
  rendered as app icon + favicon product images (dock and browser-tab mockups, favicon size
  ladder, contact sheet in `build/icon-concepts/`); the human chose the cocoon — a pod hanging
  from a thread with two silk wraps, "hatches exactly when you need it". `Scripts/render-icons.swift`
  redraws it (wrap chords refined to curved bands crossing the pod); every app icon size, favicon
  and the favicon SVG regenerate from that one script. (2) Scrubbed the stray flag reference from
  the public repo: the two icon commit bodies reworded via history rewrite (`dev` force-pushed,
  merged `feature/icon-two-circles` deleted from origin), PR #5 body edited, D-013 wording
  neutralized. Residual: the phrase still exists inside old commit *file contents* (e.g. D-013's
  text as committed in `71d5537`) and in PR #5's frozen commit list — a full
  `git filter-repo` purge would clear those if ever needed.
- **Verified:** `Scripts/check.sh` end to end — lint (pre-existing Dialogs.swift warnings only),
  generate, build OK, **89 tests / 12 suites pass**, site builds (8 assets copied). Icon sizes and
  favicon SVG regenerated from the one script and eyeballed at 1024/512/48/32 px.
- **Landing:** `feature/icon-cocoon` → PR → `dev` (D-007), this session.
- **Blocked by:** (1) the manual Finder round trip on the fixed extension (enable in System
  Settings → Extensions (Finder Extensions), relaunch Finder, right-click a project folder);
  (2) human-only GitHub settings for D-007: the `release:patch` / `release:minor` /
  `release:major` labels and `dev` as default branch with required-PR protection.
- **Next action (new session):** take the Finder round-trip confirmation, then the release PR from
  `dev` to `main` with one `release:*` label (ship-release skill) → tap publish procedure → manual
  site deploy when the human asks. When the first release ships, flip the site from "coming soon"
  to real download links and enable the brew command copy.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
