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

- **Phase:** 4 — launch. Phase 3 (promo site) is merged to `dev` (PR #3).
- **Done this session:** (1) **D-011** — root-caused the invisible "Dormant ▸" Finder menu: `pkd`
  rejected the appex ("plug-ins must be sandboxed"), so it was never registered anywhere.
  `DormantFinder` now carries App Sandbox (new `DormantFinder.entitlements` + `project.yml`
  wiring); the app stays unsandboxed. Extension display name fixed to "Dormant" (was
  "DormantFinder"), so the Finder submenu reads "Dormant ▸". (2) **D-012** — Clean stays one-way
  (the human's choice over a rebuild path): every Finder/app action now registers its project in
  the registry (`ActionPresenter.resolveRecord`), fixing "no entry in the app" after a Finder Clean;
  the Clean preview states the removal is permanent and that development state is rebuilt with the
  project's own dependency commands; Restore stays archive-only. (3) Site: "Coming soon for macOS"
  CTAs replace the download buttons and the brew line keeps its command with a disabled Copy
  button plus a "Not published yet" note (still zero client JS).
- **Verified:** `Scripts/check.sh` end to end — lint clean, build OK, **89 tests / 12 suites pass**,
  site builds. Rebuilt Debug appex carries exactly `app-sandbox` + Debug `get-task-allow`;
  `pluginkit -mAvvv -p com.apple.FinderSync` lists exactly one `com.dormant.Dormant.Finder`
  ("Display Name = Dormant"). Live Finder test: Clean on `dev-rig` removed `target/` (524K left).
  Not verified: CLI `open dormant://…` did not reach the running app (Finder's `NSWorkspace`
  delivery does work — the human's Finder Clean ran through it); note as a possible follow-up.
- **Landing:** `feature/finder-menu-and-coming-soon` → PR → `dev` (D-007), merged this session.
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
