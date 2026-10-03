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

- **Phase:** 4 — launch; **v0.1.0 is published** (tag + GitHub release + Homebrew tap) and the
  site carries the download links.
- **Prior (launch prep):** release labels created, the mis-tagged v0.0.10 yanked, v0.1.0 cut via
  PR #13, tap published and brew verified end to end, site flipped to real download links
  (PRs #14–15).
- **Done this session (2026-10-03):** Finder extension auto-enablement (D-026) — the app elects
  `com.dormant.Dormant.Finder` at launch until first observed enabled (documented `pluginkit -e
  use`, embedded appex registered best-effort), shows a one-time success alert, falls back to a
  System Settings deep-link dialog when it cannot enable (quiet retry on later launches, one
  prompt ever), and the menu bar shows "Enable Finder Extension" while the extension is
  disabled; `FinderExtension` in `DormantCore` with parser/command tests; docs updated (D-026,
  product, architecture).
- **Verified:** `Scripts/check.sh` green — lint, generate + build, **128 tests / 19 suites
  pass** (was 123 / 18), site build. Live end-to-end on macOS 27.2: `pluginkit -e ignore` +
  UserDefaults flags cleared (fresh-install simulation) → debug build launched → extension back
  to `+` and `finderExtension.autoEnabled` written; the debug plugin registration was removed
  afterwards and the `/Applications` copy left enabled; the fallback deep link opens System
  Settings.
- **Blocked by:** human-only launch smoke — first launch of the brew-installed app (Gatekeeper
  → Privacy & Security → "Open Anyway") and a visual pass: the success alert, the deep-link
  pane, and the "Dormant ▸" menu after auto-enable; the UI batch's hands-on pass also remains
  open.
- **Next action:** review + merge this PR (green check) → D-026 ships with the next release;
  then the human smoke pass → mark Phase 4 complete.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
