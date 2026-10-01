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

- **Phase:** 4 — launch, with a pre-release UI/distribution batch in flight.
- **Done this session:** (0) PR #7 (D-015–D-017) and the D-014 icon work are merged into `dev`;
  `dev` pulled. (1) **App-copy cleanup** (human-approved disposition): the Release build is
  installed as `/Applications/Dormant.app`; the three build-artifact copies (`build/Debug`,
  `build/Release`, DerivedData `Debug`) are deleted — `~/.dormant` untouched. (2) **Docs-first for
  the new batch**, decisions recorded as **D-018–D-024**: Liquid Glass on a macOS 26 floor
  (deployment target 26.0, cask `>= :tahoe`), DMG as the release artifact (supersedes the zip;
  `Scripts/make-dmg.sh`, cask installs from the DMG), Git Clone into Folder (Finder empty space →
  URL prompt → clone → register → open in VS Code), search + stale badges (30-day threshold),
  savings dashboard + batch clean (explicit opt-in), auto-archive suggestions (never automatic),
  menu-bar quick actions. `product.md` / `architecture.md` / `development.md` updated to match.
- **In progress:** the implementation on `feature/ui-glass-batch` (toolchain gate passed: Xcode
  27.0, 26+ SDK), following the plan in `~/.commandcode/plans/dormant-ui-glass-batch.md`.
- **Verified:** `mdfind` + `ls` confirm exactly one `Dormant.app` (`/Applications`); the app
  launches from there (Finder extension re-registration). Implementation checks not yet run.
- **Blocked by:** (1) human-only GitHub settings for D-007: the `release:patch` / `release:minor`
  / `release:major` labels (branch default is `dev` already — PR protection unknown); (2) the
  human's hands-on Finder round trip for D-015–D-017 is assumed done (told "first two are done").
- **Next action (new session):** finish `feature/ui-glass-batch` per the plan (UIConstants/sizing →
  icons → glass → git clone → search/stale → dashboard/clean → menu-bar → suggestions → DMG),
  `Scripts/check.sh` green, then push + PR → `dev`. After merge: human hands-on pass of the new UI
  and features, then the release PR `dev` → `main` with one `release:*` label (ship-release skill)
  → tap publish → manual site deploy when the human asks → flip the site to real download links.

---

### Handoff note format (replace the section above when you stop mid-phase)

- **Phase:** <number and name>
- **Done this session:** <what actually landed>
- **Verified:** <what was run, what was observed — not "it works">
- **Blocked by:** <nothing, or the exact question waiting on the human>
- **Next action:** <the single first thing to do next>
