# Decisions

Append-only log of settled decisions. New entries get the next number, a date, and a sentence of
context. If a decision is reversed, add a new entry that supersedes the old one — never edit
history. The agent records decisions here **before** implementing them (see `AGENTS.md`, rule 2).

## D-001: Stack selection — native Swift + Xcode, zero third-party runtime deps

**Date:** 2026-09-26

**Context:** Dormant is a local-first macOS developer utility (menu bar app + Finder integration,
SQLite-backed project registry, local compressed archive store). Chosen with the human via the
`project-bootstrap` skill; the human selected the full-Xcode toolchain.

**Decision:**

- **Language / toolchain:** Swift 6.4 (swift-driver 1.168.6, swiftlang-6.4.0.34.1) on macOS 27.0,
  built with Xcode 27.0 (build 27A266a) — resolved live 2026-09-26 via `xcodebuild -version`.
  Swift 5 language mode (`SWIFT_VERSION: 5.0`) on the 6.4 compiler. Deployment target: macOS 14.0.
- **UI:** SwiftUI for the main window, dialogs, and `MenuBarExtra` menu bar item; AppKit where
  SwiftUI doesn't reach (Finder Sync, `NSWorkspace`).
- **Finder integration:** Finder Sync extension (`com.apple.FinderSync` appex) providing the
  inline "Dormant ▸" context submenu; destructive actions route to the app via a `dormant://` URL
  scheme so confirmation UI always runs in the app.
- **Project / build management:** XcodeGen 2.46.0 (Homebrew) — `project.yml` is committed, the
  `.xcodeproj` is generated. Xcode builds the app and the embedded extension.
- **Storage:** system SQLite (libsqlite3) registry at `~/.dormant/registry.sqlite`; archive store
  at `~/.dormant/store/` holding gzip tarballs (`/usr/bin/tar`, bsdtar) of a project's core files.
  Git inspection shells out to the system `git`. No third-party runtime dependencies.
- **Tests:** Swift Testing (bundled with the toolchain), run by `xcodebuild test`.
- **Lint / format:** `swift-format` (bundled with the toolchain; invoked as `xcrun swift-format` —
  the bare binary is not on PATH).
- **Check command:** `Scripts/check.sh` — lint → `xcodegen generate` → build → test. Definition of
  done for every change; CI runs exactly it.
- **CI:** GitHub Actions on the `macos-26` runner image (GA since 2026-02; `macos-latest` now
  points at it), `actions/checkout@v7.0.1`, installing XcodeGen via Homebrew.
- **Deployment target(s):** none. Local ad-hoc-signed builds only — no certificates, signing,
  notarization, or store submission (explicit product constraint). The manual release path lives
  in `.commandcode/skills/ship-release`.

**Considered and rejected:**

- **Electron / Tauri / cross-platform desktop kit** — Finder Sync and native menu bar status
  items are Apple-only; you'd still write Swift. Two stacks for zero gain.
- **Rust core + Swift shell** — a cross-language boundary in a Mac-only app, for no user benefit.
- **Command Line Tools-only SwiftPM build** (hand-assembled `.app`/`.appex`, ad-hoc signing) —
  avoids the Xcode install but is a nonstandard bundle pipeline Apple doesn't document for Finder
  Sync. Human chose full Xcode instead.
- **Finder Quick Action / Services menu** instead of a Finder Sync extension — simpler, but it
  lives in "Services", not the inline "Dormant ▸" submenu the product calls for.
- **Third-party libs (GRDB, libgit2, zstd, logging kits)** — system libsqlite3, `git`, and bsdtar
  cover every need; zero runtime deps keeps the build unbreakable and auditable.
- **tar.zst archives** — zstd ships on no stock macOS; gzip tarballs are universal and let the
  user inspect their own archive with stock tools.

**Cost / risk:** the dev Mac needs Xcode (~15 GB, in progress at decision time); ad-hoc signing
means the Finder extension may need a one-time enable in System Settings; the Finder Sync
app↔extension plumbing is the least-documented part of the build; CI runs macOS 26 / Xcode 26–27
while the dev Mac is macOS 27 — the macOS 14 deployment target keeps that gap benign.

## D-002: Branching and CI model — `dev` is the work branch, `main` is the release branch

**Date:** 2026-09-26

**Context:** Set by the human right after bootstrap: keep day-to-day work off `main`, and let the
CI weight follow the branch.

**Decision:**

- `dev` is the default work branch. Every change lands on `dev` through a pull request
  (work branch → PR → merge into `dev`).
- `main` is the release branch. Release tags (`v*`) are cut from `main` only, and full CI runs on
  pushes to `main` (`.github/workflows/ci.yml`).
- PRs run the check command (`Scripts/check.sh`) against any base; a green PR build is the merge
  gate into `dev`.
- The GitHub default branch is set to `dev` by the human.

**Considered and rejected:**

- **Trunk-only development on `main`** — mixes release state with work in progress.
- **Per-version release branches** — overkill for a local-first utility.
- **Full CI on every push to `dev`** — PR checks are the gate; runner time is better spent on
  `main`.

**Cost / risk:** `dev` → `main` merges (PR) are the only path to a release; tags must be cut from
`main` (recorded in the ship-release skill).

## D-003: Archive scope — the tarball holds everything left after clean

**Date:** 2026-09-26

**Context:** The shorthand "tar core files" left open what happens to files that are neither core
nor confidently regenerable. Archive removes the working copy wholesale, so nothing may be lost
in the process.

**Decision:** The tarball contains **everything remaining after the clean step** — core files and
unclassified files alike. `manifest.json` labels each file's kind (`core | unclassified`). This
refines the "tar core files" shorthand in `architecture.md` and matches `product.md`'s "compress
what remains". Approved by the human 2026-09-26 (phase 2 design, D4).

**Consequences:**

- The manifest carries a per-file `kind` label, so core and unclassified content stays
  distinguishable inside the archive.
- Restore extracts the whole archive and never filters what it finds — unclassified files
  round-trip untouched.
- Consistent with safety rules 4 and 10: only confidently classified regenerable paths are ever
  removed; everything else survives archive → restore.

## D-004: Archive lifetime — delete the store after a checksum-verified restore

**Date:** 2026-09-26

**Context:** After a restore is verified, the archive in `~/.dormant/store/<project-id>/` is a
second copy of the user's source (safety rule 9: avoid storing unnecessary copies of user source
code).

**Decision:** Once restore verification passes (extraction checked against the manifest
checksums), the project's store directory is deleted. If verification fails, the archive is kept
(and the extracted tree is left for inspection). Approved by the human 2026-09-26 (phase 2 design,
R1).

**Consequences:**

- After a successful restore there is exactly one authoritative copy of the project — the working
  tree.
- A failed restore never loses the archive; the error path keeps both the archive and the
  extracted tree.
- Restore ends with the registry update (`state=active`, archive row removed) followed by store
  deletion; nothing is deleted before verification succeeds.

## D-005: Regenerable-name scoping — ambiguous basenames only in manifest-sibling scope

**Date:** 2026-09-26

**Context:** Basenames like `dist`, `build`, `bin`, `obj`, `target` are regenerable output in one
project and hand-made content in another. The shorthand pattern example in `architecture.md`
over-matched such names project-wide.

**Decision:** Ambiguous basenames (`dist`, `build`, `bin`, `obj`, `target`) match **only in
manifest-sibling scope** (e.g. `target/` only directly beside `Cargo.toml`; `bin`/`obj` only next
to a `*.csproj`). Unambiguous names (`node_modules`, `.venv`, `__pycache__`, …) match anywhere in
the project. Stricter than the shorthand example in `architecture.md`; a hand-made `docs/build/`
or `assets/target/` is never classified as regenerable. Approved by the human 2026-09-26 (phase 2
design, A-scope).

**Consequences:**

- Every classification pattern carries an explicit scope; the full manifest→pattern mapping lives
  in `architecture.md` and is the contract the code follows.
- Generic cache names are matched only through a rule for a detected ecosystem — never bare.
- The error direction is safe: some genuinely regenerable directories may be left on disk, which
  costs space, never data (safety rule 4).

## D-006: Open action — a user-configured editor command, falling back to opening the folder

**Date:** 2026-09-26

**Context:** `product.md` promises **Open** launches the project "in the user's configured/default
development environment", but macOS has no default handler for "open this folder in a dev
environment", so the exact behavior was undefined.

**Decision:** Open runs a user-configured command template from the app's settings (e.g.
`cursor {path}`, `xed {path}`; `{path}` is substituted with the project path). When no command is
configured, Open falls back to opening the project folder with `NSWorkspace`. The action never
modifies the project. Approved by the human 2026-09-26.

**Consequences:**

- The app settings gain one field: the editor command template (phase 2 UI slice).
- Behavior is per-user and explicit; nothing is guessed from the environment.
- Fallback keeps the action useful with zero configuration.

## D-007: Branching and labeled automated releases (pulled from the template, supersedes the release mechanics of D-002)

**Date:** 2026-09-26

**Context:** The upstream template (`template-app-plus-site`, `dev`) replaced the manual
tag-on-`main` release flow with a labeled-PR release policy. Imported into this repo on the
human's instruction ("compare and take the pull"). D-002's `dev`/`main` split stands; this entry
supersedes its manual tagging step and the tag-triggered `.github/workflows/release.yml`.

**Decision:**

- `dev` is the default integration branch. Changes reach `dev` through a feature-branch pull
  request; never commit or push directly to `dev` or `main`.
- A release is proposed by a pull request from `dev` to `main` carrying exactly one
  `release:patch`, `release:minor`, or `release:major` label.
- Release-related workflows run only after a merge to `main`. The release workflow applies the
  labeled bump to the version source (`MARKETING_VERSION` in `project.yml`), updates
  `CHANGELOG.md`, creates the matching `v<version>` tag, and publishes a GitHub release. A merge
  without a release label does not publish a release.
- `dev` carries unreleased work between releases and may match `main` immediately after one.
  Product and site deployments remain manual.

**Consequences:**

- `.github/workflows/release.yml` must be reworked from the tag-triggered build to the
  labeled-merge bump/tag/publish flow — tracked as pending work in `docs/status.md`
  (reworked 2026-09-26).
- GitHub repository settings are required: default branch `dev`, required-PR protection for `dev`
  and `main`, and the three `release:*` labels. These are human-only settings (API tokens here
  cannot change them).
- `ship-release` and `docs/development.md` describe the labeled flow from now on.

## D-008: Agent operating model (pulled from the template)

**Date:** 2026-09-26

**Context:** The upstream template replaced the PM/subagent delegation model after subagent runs
proved unreliable. Matches the human's instruction the same day ("do not delegate to subagents
… do it yourself").

**Decision:** The primary agent acts as senior architect and owns requirements analysis,
architecture, documentation, code generation, integration, testing, and final verification.
Subagents are optional and restricted to one sequential, read-only discovery or
evidence-gathering request; they never implement, make architecture decisions, edit
documentation, or verify changes. A subagent's summary is evidence, never proof.

**Consequences:**

- `AGENTS.md` carries the senior-architect workflow (merged with this repo's working
  preferences).
- The project agents in `.commandcode/agents/` remain defined but are no longer the execution
  path for implementation or verification.
- Every change lands through the primary agent, with the repository check command as the gate.

## D-009: Site stack — Eleventy 3.1.6, static output, zero client JS

**Date:** 2026-09-26

**Context:** Phase 3, the promo site. `docs/architecture.md` originally scoped `site/` as
hand-written "static HTML/CSS". The human asked for a lightweight framework ("go use a lightweight
framework") and selected Eleventy from the presented alternatives (2026-09-26).

**Decision:**

- **Generator:** Eleventy 3.1.6 (`@11ty/eleventy`, resolved live 2026-09-26 via
  `npm view @11ty/eleventy version`; requires Node >= 18, dev machine has Node 24.19.0). Nunjucks
  templates in `site/src/`, static output to `site/_site/` (gitignored).
- **Client JS:** none. Hand-written CSS only; no client-side framework.
- **Dependencies:** Eleventy is the single devDependency (`site/package.json`, lockfile
  committed); zero runtime dependencies. Repo shape unchanged — the site imports no product code.
- **Checks:** `Scripts/check.sh` builds the site (`npm ci --include=dev` + `npm run build` in
  `site/`; the dev-dependency install is explicit because shells with `NODE_ENV=production` omit
  dev dependencies) as its final step; CI runs exactly the check command, so a broken site fails
  the build.
- **Deploy:** static `site/_site/` output, deployed manually per `ship-release`; no host chosen
  yet (phase 4).

**Considered and rejected:**

- **Astro** — component SSG with zero-JS output, but a much heavier toolchain than a 1–2 page
  promo site needs.
- **Vite + vanilla TS** — a bundler, not a site generator; page structure and any shared layout
  would be hand-rolled.
- **Plain HTML + Pico.css** — no build at all, but the human asked for a framework and future
  pages (changelog) would share layout by copy-paste.

**Cost / risk:** introduces the repo's first Node toolchain (site-only; the product build stays
Swift/Xcode); Eleventy major releases can change template defaults — the committed lockfile pins
the build.

## D-010: Distribution — own Homebrew tap, no Apple Developer Program

**Date:** 2026-09-26

**Context:** Asked whether Dormant can ship via Homebrew: `homebrew/cask` has required
Gatekeeper-passing (Developer ID signed + notarized) artifacts since 2026-09-01 and applies a
notability bar (self-submission: 225 stars, or 90 forks, or 90 watchers). The human rejected the
paid Apple Developer Program route ("its expensive") and chose the free path.

**Decision:**

- Ship via our own third-party tap `PrakashSewani/homebrew-tap`:
  `brew tap PrakashSewani/tap && brew install --cask dormant`. Homebrew explicitly permits
  unsigned software in third-party taps.
- D-001's no-signing/no-notarization stance stands and is now load-bearing; the Apple Developer
  Program stays out (product.md non-goal).
- No `homebrew/cask` submission for now (Gatekeeper + notability requirements). Revisit only as
  its own decision if the app gains traction.
- Tap `version`/`sha256` bumps are manual, documented as exact commands in the `ship-release`
  skill (no cross-repo PAT or secrets). Automation is optional later.
- Install friction is accepted and documented: the quarantined app needs the one-time System
  Settings → Privacy & Security "Open Anyway" approval on first launch (`--no-quarantine` is being
  removed from brew). The cask `caveats`, the README, and the site all print this.
- Safety alignment: the cask's `zap` never touches `~/.dormant` (registry + archive store = user
  source code); only the app's preferences plist is zapped.

**Considered and rejected:**

- **Apple Developer Program + `homebrew/cask` submission** — $99/yr plus real identity and
  notarization; the human rejected the cost and it reverses a product non-goal.
- **Source-building formula** — building the GUI app needs full Xcode + XcodeGen; a poor fit for a
  formula and for users.
- **`sha256 :no_check`** — pinning the checksum is the point; every release bump carries one.

**Cost / risk:** one Gatekeeper dialog on first launch (same as direct download); the tap is not
Homebrew-endorsed (their policy states this plainly); a forgotten manual bump leaves `brew upgrade`
lagging behind the GitHub release.

## D-011: Sandbox split — the Finder extension is sandboxed, the app is not

**Date:** 2026-09-26

**Context:** The "Dormant ▸" Finder menu never appeared on any right-click — on folders or on
empty space. The cause was at registration, not in Finder: `pkd` rejected the appex at discovery
with `Ignoring mis-configured plugin at […/DormantFinder.appex]: plug-ins must be sandboxed`
(`log show`), so `pluginkit -mAvvv -p com.apple.FinderSync` never listed it and System Settings
had nothing to enable. D-001 turned App Sandbox off repo-wide; macOS loads no non-sandboxed app
plugin, whatever the extension does.

**Decision:**

- `DormantFinder` is sandboxed (`com.apple.security.app-sandbox` in
  `Sources/DormantFinder/DormantFinder.entitlements`) — a hard platform requirement for plugin
  discovery. The extension only reads Finder's selected/target URLs and forwards `dormant://`
  URLs, so the sandbox costs nothing functionally.
- `DormantApp` and `DormantCore` stay **unsandboxed**: the app must operate on arbitrary project
  folders and shell out to `git`, `/usr/bin/tar`, and the user's package managers. D-001's "no
  App Sandbox" stands for them.
- Signing stays ad-hoc (D-001/D-010); entitlements are embedded ad-hoc, no certificate needed.

**Considered and rejected:**

- **Sandboxing the app as well** — every project folder would need user-selected file grants and
  the shelled-out install commands would fight the sandbox; nothing user-facing gains.
- **Replacing Finder Sync with a Quick Action/Services menu to dodge the sandbox** — D-001 already
  rejected it (wrong menu placement), and the sandbox requirement is not a reason to move menus.
- **Temporary-exception entitlements for the appex** — it reads no files itself; over-granting.

**Cost / risk:** the ad-hoc-signed extension still needs a one-time enable in System Settings →
Extensions (Finder Extensions) plus a Finder relaunch; any change to the appex's entitlements
changes its code signature and can require re-approval.

## D-012: Clean stays one-way; every action registers its project in the registry

**Date:** 2026-09-26

**Context:** Live Finder testing: Clean on `dev-rig` reclaimed space, but the project never appeared
in the app and Restore reported no registry entry. Two causes: (1) the clean path in
`ActionPresenter` never wrote to the registry — only Archive and Open Repository registered
projects, so a Finder-driven Clean left no trace in the app; (2) an expectation gap — the natural
"undo" for a Clean was taken to be Restore, but Clean archives nothing (`~/.dormant/store/` empty)
and Restore is archive-only by design. Alternatives were presented: Restore falls back to running
the detected install commands when there is no archive; a separate "Rebuild dev state" action;
Clean stays one-way. **The human chose: Clean stays one-way.**

**Decision:**

- Clean is permanent-by-design: regenerable state is removed, never archived. Getting a working dev
  environment back afterwards is the project's own dependency commands' job (`cargo build`,
  `npm install`, …) — Dormant does not run them for a cleaned project. Restore remains strictly
  archive-only (D-003/D-004 flow unchanged).
- Every Finder/app action registers or refreshes its project in the registry before doing its work
  (`Scanner.register(projectAt:)`, which preserves `state` on existing rows), so the app's project
  list always reflects what the user touches — including a Clean the user then cancels.
- The Clean preview dialog states plainly that the removal is permanent and that development state
  is rebuilt later with the project's own dependency commands.

**Considered and rejected:**

- **Restore falls back to install commands when no archive exists** — the human wants Clean visibly
  one-way; a silent rebuild path would blur the two actions.
- **A separate "Rebuild dev state" action** — deferred; resurface only if the one-way feel becomes
  annoying in practice.

**Cost / risk:** there is no in-app undo for a Clean; the dialog warning and the classification
invariant (only confidently regenerable paths are ever removed) are the guardrails.

## D-013: Icon system — one crescent-moon mark, script-rendered at every size

**Date:** 2026-09-26

**Context:** The app had no icon (plain generic bundle) and the site had no favicons. Needed for
the Finder/dock identity and for release/distribution surfaces (Homebrew cask `icon_url`, site,
README).

**Decision:**

- **Mark:** two circles — a paper (`#f4f1e8`) disc with an offset circular hole (a tapering
  ring), centered by its bounding box — on a hibernate (`#3c5a43` → `#213427`) squircle. The first
  mark, cleaned up: no spark, no seam. A crescent moon was tried and rejected (reads as the
  Pakistan flag crescent); one idea, no ornament; readable down to 16px.
- **One source, script-rendered:** `Scripts/render-icons.swift` (AppKit/CoreGraphics, no
  dependencies) draws the mark and writes every raster size. The design lives in the script; no
  binary master file.
- **Variants:** the macOS Big Sur grid (squircle at 80.5% with transparent margin) for the app
  icon; a full-bleed rounded square for web favicons; full-bleed square for `apple-touch-icon`
  (iOS applies its own mask).
- **Sizes delivered:** `Assets.xcassets/AppIcon.appiconset` 16/32/64/128/256/512/1024 (the
  standard mac set), `site/src/` `favicon.svg` (generated from the same geometry),
  `favicon-16/32/48.png`, `apple-touch-icon.png` (180), `icon-512.png` / `icon-1024.png` for
  publishing surfaces.
- **Wiring:** `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` + `CFBundleIconName` for the app;
  `<link rel="icon">` tags in `site/src/_includes/base.njk`; PNGs/SVG as Eleventy passthrough
  copies.

**Considered and rejected:**

- **A binary design file (`.sketch`/`.figma`) as master** — nothing in the repo could regenerate
  sizes from it; the script is the master.
- **A folder/archive glyph** — too busy at favicon sizes; the eclipse carries the "project going
  to sleep" promise alone.
- **A crescent moon** — tested and cut: reads as the Pakistan flag crescent at icon sizes.

**Cost / risk:** the design is code — visual tweaks mean editing the script and re-running it
(`swift Scripts/render-icons.swift`); every raster size and the favicon SVG regenerate from that
one geometry, so nothing can drift out of step.
