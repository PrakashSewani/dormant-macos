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

## D-013: Icon system — one mark, script-rendered at every size

**Date:** 2026-09-26

**Context:** The app had no icon (plain generic bundle) and the site had no favicons. Needed for
the Finder/dock identity and for release/distribution surfaces (Homebrew cask `icon_url`, site,
README).

**Decision:**

- **Mark:** two circles — a paper (`#f4f1e8`) disc with an offset circular hole (a tapering
  ring), centered by its bounding box — on a hibernate (`#3c5a43` → `#213427`) squircle. The first
  mark, cleaned up: no spark, no seam. A crescent moon was tried and rejected (at icon sizes it
  reads as a flag crescent); one idea, no ornament; readable down to 16px.
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
- **A crescent moon** — tested and cut: at icon sizes it reads as a flag crescent.

**Cost / risk:** the design is code — visual tweaks mean editing the script and re-running it
(`swift Scripts/render-icons.swift`); every raster size and the favicon SVG regenerate from that
one geometry, so nothing can drift out of step.

## D-014: Mark change — the cocoon (supersedes the mark chosen in D-013)

**Date:** 2026-09-27

**Context:** The ring mark was clean but said nothing. The human asked for a witty mark and
reviewed nine script-rendered candidates — paused, folder with Z, standby glyph, tucked-in,
vacuum bag, tin can, cocoon, hammock, seed — each delivered as app icon and favicon product
images (dock and browser-tab mockups, favicon size ladder). The human chose the cocoon.

**Decision:**

- **Mark:** a cocoon hanging from a thread — a tapered paper pod with two wrap chords, on the
  D-013 hibernate plate. The joke is the product promise: the project is dormant and hatches
  exactly when you need it (Restore).
- Everything else in D-013 stands: one idea, no ornament, bbox-centered, every raster size and
  the favicon SVG regenerated from `Scripts/render-icons.swift`.

**Considered and rejected:**

- **Paused (pause bars)** — reads as a media control, not this product.
- **Folder with a Z** — D-013 already cut a folder glyph as too busy at favicon sizes.
- **Standby glyph** — reads as "power", not "sleep".
- **Tucked-in, vacuum bag, tin can, hammock** — charming at 512 px, mush at 16 px.
- **Seed** — "dormant is what seeds do" only lands with the caption.
- **The ring mark** — correct, and boring; the human asked for wit.

**Cost / risk:** the wrap chords fade below ~24 px (the pod-and-thread silhouette still reads);
a cocoon is less literal than a folder for a file tool — the tagline and site copy carry the
metaphor.

## D-015: External tools — hardcoded lookup paths and hard errors (supersedes D-006)

**Date:** 2026-09-30

**Context:** Restore's dependency commands ran via `/usr/bin/env` with the GUI app's inherited
launchd PATH (`/usr/bin:/bin:/usr/sbin:/sbin`), so `npm install` exited 127 ("no such file or
directory"): tool managers like nvm are only on PATH inside a shell profile (`~/.zshrc`,
`~/.zprofile`), which a GUI app never sees. The same blind spot hit every package manager and
`code`. D-006's Open action asked for a user-configured editor command and silently fell back to
opening the folder in Finder. The human: fix it for **every** package manager, hardcode the
lookup paths ("don't ask for custom path from user"), and when a tool is unavailable throw
errors — never fall back to opening Finder. Open is `code .` (VS Code), hardcoded.

**Decision:**

- **`ToolLocator` searches a hardcoded, ordered list of known install locations** for every
  external tool — all install commands (`npm`, `pnpm`, `yarn`, `bun`, `uv`, `poetry`, `python3`,
  `cargo`, `dotnet`, `go`) and `code`: tool-manager dirs (`~/.nvm/versions/node/*/bin`, newest
  node first, `~/.volta/bin`, `~/.bun/bin`, `~/.cargo/bin`, `~/.asdf/shims`, `~/.local/bin`,
  `~/go/bin`), Homebrew (`/opt/homebrew/bin`, `/opt/homebrew/sbin`), `/usr/local/bin`,
  `/usr/local/sbin`, `/usr/local/share/dotnet`, then the system dirs (`/usr/bin`, `/bin`,
  `/usr/sbin`, `/sbin`). `code` additionally searches
  `/Applications/Visual Studio Code.app/Contents/Resources/app/bin`. An executable name
  containing `/` (`.venv/bin/python`) resolves against the project root. No user-facing
  configuration anywhere.
- **A missing tool is a hard error.** An install command whose executable is not found fails with
  exit status 127 and a message naming what was searched; later commands do not run. Open shows
  an error alert. D-006's Finder fallback is removed.
- **Open runs `code .`** in the project directory. The editor-command setting is deleted.

**Considered and rejected:**

- **Login shell (`zsh -l -c`)** — still misses `~/.zshrc` tool managers (nvm is sourced there);
  an interactive shell sources rc files with side effects and stray output.
- **User-configurable tool paths** — the human wants it hardcoded.
- **Fallbacks (open Finder, skip the command)** — the human wants thrown errors.

**Cost / risk:** a tool in an exotic location is not found; the error message lists the searched
directories so the gap is visible. Supporting a new manager means editing one list in
`ToolLocator`.

## D-016: Finder submenu — Clean, Archive, Restore, Import Folder in Dormant

**Date:** 2026-09-30

**Context:** The Finder "Dormant ▸" submenu carried six items (Open, Clean, Archive, Restore,
Project Info, Open Repository). The human wants the hover menu to show the folder actions plus a
way to get a folder into Dormant from Finder: Clean, Archive, Restore, and "Import Folder in
dormant" — the app's scan function.

**Decision:**

- The Finder "Dormant ▸" hover submenu is exactly: **Clean, Archive, Restore, Import Folder in
  Dormant**. Routing stays D-011's `dormant://` URLs into the app.
- **Explicit "Dormant" root item:** Finder inserts the returned `NSMenu`'s items flat into the
  context menu and never displays the menu's title — confirmed on the human's machine. The
  extension therefore nests its four actions under an explicit "Dormant" root item with a
  submenu, which is what produces the hover flyout.
- **Import Folder in Dormant** runs the same scan as the app's Scan… (`Scanner.scan(roots:)`,
  depth 3) on the selected folder and reports added / updated / reappeared projects in an alert.
- Open, Project Info and Open Repository remain in the app's project-list context menu only.

**Considered and rejected:**

- **Keeping all six items in Finder** — the human asked for these four.
- **Open from Finder** — `code .` belongs to the app's project list (D-015).

**Cost / risk:** the three app-only actions are less discoverable from Finder; they stay one
click away in the app's project list.

## D-017: Directories are first-class — grouping, whole-folder sizes, and menu placement

**Date:** 2026-09-30

**Context:** A developer keeps projects in a few top-level folders (e.g. `~/Projects/Work`,
`~/Projects/Personal`) and wants to see how much disk each of those folders eats, not just each
project. The human also scoped the new Finder action: right-clicking a **folder** must not offer
"Open Directory in Dormant"; right-clicking **empty space** (the folder being browsed) must offer
it. Decided with the human 2026-09-30: (a) folder menu keeps exactly the D-016 four items,
(b) a "directory" is a folder explicitly imported into Dormant (Finder import/open, app Scan…),
not an auto-derived parent, (c) "space being eaten" is the **whole folder on disk** (projects,
`node_modules`, build output, untracked files), (d) "Open Directory in Dormant" shows on
empty-space clicks **everywhere** and opening adds the directory to Dormant automatically — so
the sandboxed extension needs no knowledge of the registry.

**Decision:**

- **Directories are registry state** (`directories` table, schema v2): a folder becomes one when
  imported via Finder "Import Folder in Dormant" / "Open Directory in Dormant" or the app's
  Scan…. The app maintains projects grouped under their deepest containing directory;
  ungrouped projects stay top-level.
- **Per-directory size = `SizeAccounting.totalBytes` of the whole folder subtree** — the real
  disk usage, not the sum of tracked projects. Directory rows show it alongside project rows.
- **Finder menu placement (refines D-016):** folder-item clicks → Clean, Archive, Restore,
  Import Folder in Dormant (no open-directory item); empty-space (container) clicks →
  "Open Directory in Dormant" alone. Both under the explicit "Dormant ▸" root item.
- **Open Directory in Dormant** imports the directory (registry + scan of projects inside),
  then opens the app's main window with that directory selected.

**Considered and rejected:**

- **Auto-derived parent groups** — the human wants explicit imports only.
- **Sum-of-tracked-projects as the size** — misses the regenerable state Dormant exists to
  reclaim; the whole-folder measure shows what Clean/Archive can save.
- **Menu conditional on "is inside a Dormant directory"** — rejected: showing the item
  everywhere and auto-adding avoids shared state between the sandboxed extension and the app
  (D-011).

**Cost / risk:** whole-folder sizes re-walk the subtree on every refresh (computed off the main
thread like project sizes); nested imported directories each show their own subtree size, which
is intentional ("what does this folder eat") rather than a sum-to-total.

## D-018: UI refresh — Liquid Glass on a macOS 26 floor

**Date:** 2026-10-01

**Context:** Pre-release UI batch ("before we publish can we work on the ui part"): the human asked
for Liquid Glass design, icons integrated throughout the app, and minimum button sizing ("button
uis need some min sizing they look cluttered"). Liquid Glass is the macOS 26 (Tahoe) design
language and only exists in the 26+ SDK and on 26+ runtimes. Scope decided with the human
2026-10-01: **macOS 26+ only** — real Liquid Glass, no dual design language.

**Decision:**

- **Deployment target rises from macOS 14.0 to 26.0** (`project.yml`); the Homebrew cask's
  `depends_on` becomes `>= :tahoe`. Built with Xcode 27 (26+ SDK). This supersedes D-001's
  deployment target; everything else in D-001 stands.
- **Glass:** standard controls adopt Liquid Glass natively under the modern SDK; custom chrome
  (savings summary bar, state badges, dialog headers) uses `.glassEffect` explicitly. Tasteful —
  not every surface.
- **Icons everywhere:** SF Symbols in the toolbar, table rows, context menus, dialogs and empty
  states; the script-rendered brand mark (D-013/D-014) becomes the menu-bar icon via a new
  template `Mark.imageset` emitted by `Scripts/render-icons.swift`.
- **Sizing tokens** (`UIConstants` in `DormantApp`): minimum button width, standard control size,
  dialog padding/spacing — fixing the cluttered buttons.

**Considered and rejected:**

- **macOS 14+ with availability-gated glass** — two design languages to maintain for a pre-1.0
  utility with no installed base on older macOS.
- **Modernize without glass** — the human explicitly asked for Liquid Glass.

**Cost / risk:** pre-Tahoe macOS users cannot install (accepted by the human); CI's `macos-26`
runners carry a 26+ SDK, so the raised target builds there.

## D-019: Release artifact — DMG (supersedes the zip artifact of D-007/D-010)

**Date:** 2026-10-01

**Context:** The human wants installs to arrive as a DMG with the drag-to-Applications layout
("when people do brew install i want user to get dmg file they will drag the app to application
folder"). The release published `Dormant-v<version>.zip` and the cask unpacked the zip.

**Decision:**

- The GitHub release artifact becomes **`Dormant-v<version>.dmg`**, built by
  `Scripts/make-dmg.sh` using `create-dmg` (Homebrew; build-time only) with the standard
  drag-to-Applications window (app + `/Applications` symlink).
- The cask `url` points at the DMG: `brew install --cask` mounts it and copies `Dormant.app` into
  `/Applications` automatically (brew users never drag), while manual downloaders get the same
  DMG with the drag affordance. One artifact serves both.
- `release.yml`, the ship-release procedure/cask template, and the site download copy follow.

**Considered and rejected:**

- **Zip + DMG as two artifacts** — two checksums and two bump steps for no audience gain.
- **Plain `hdiutil` DMG** (no layout) — saves a CI dependency but loses the drag affordance the
  human asked for.

**Cost / risk:** `create-dmg` is a CI/dev Homebrew dependency only; the zero-runtime-dependency
rule (D-001) is untouched.

## D-020: Git Clone into Folder — Finder empty space → prompt → clone → open in VS Code

**Date:** 2026-10-01

**Context:** The human's feature idea: right-click empty space in a folder in Finder → Dormant
offers "Git Clone into Folder" → asks for the clone link → clones into that folder → opens the
clone in VS Code automatically.

**Decision:**

- The Finder empty-space (container) menu gains **"Git Clone into Folder in Dormant"** beside
  "Open Directory in Dormant", routing `dormant://git-clone?path=<folder>` (D-011/D-017 pattern —
  the extension never does work itself).
- The app shows a dialog asking for the repository URL (https/ssh/git@ forms, validated); the
  clone lands in `<clicked folder>/<name derived from the URL>` (derived name shown as a preview).
- On success: register the clone in the registry (`Scanner.register(projectAt:)`) and open it with
  `code .` (D-015) automatically. Failure shows the git stderr in an alert; nothing else changes.
- `CloneEngine` in `DormantCore` (pure remote-URL/name helpers + `ProcessRunner` over
  `/usr/bin/git`), unit-tested without network.

**Considered and rejected:**

- **Cloning inside the sandboxed extension** — D-011: the extension only routes URLs.
- **Pasteboard-driven, no prompt** — the human wants to be asked for the link.
- **Asking for the target folder too** — the clicked folder is the target by definition.

**Cost / risk:** cloning runs with the user's own git credentials (ssh agent / credential helper),
exactly like terminal git; errors surface stderr verbatim.

## D-021: Project list — search + stale badges

**Date:** 2026-10-01

**Context:** UI batch (with D-022–D-024, chosen by the human from the proposed feature list).

**Decision:**

- A search field filters the project list by name and path; groups with no matches hide while
  filtering.
- A gray **"Stale"** badge marks active projects whose last commit is older than **30 days**
  (constant in `DormantCore`); non-repos and git-unavailable rows get no badge. `GitInspector`
  gains `committerDate` (`git log -1 --format=%ct`), fetched in the existing off-main-thread
  refresh pass.

## D-022: Savings dashboard + batch clean (explicit, opt-in)

**Date:** 2026-10-01

**Decision:** A summary bar above the project list shows total reclaimable space across active
projects ("X reclaimable across N projects"). "Clean All…" previews a per-project breakdown
(biggest first) and, only after one explicit confirm, runs the existing per-project
`CleanEngine` plan/execute sequentially and reports one summary. Nothing runs automatically.

## D-023: Auto-archive suggestions — suggestions only, never automatic

**Date:** 2026-10-01

**Decision:** When active projects have been idle over **30 days** (last commit; git-unavailable
projects excluded), a non-intrusive banner offers "Review…"; the review dialog lists candidates
with a per-project "Archive…" that reuses the standard Archive confirm flow. Dormant never
archives on its own (safety rules 5–6).

## D-024: Menu-bar quick actions

**Date:** 2026-10-01

**Decision:** The menu-bar extra lists up to 10 registry projects with one-click **Open**, and
**Restore…** for dormant ones, above the existing "Open Dormant" / "Quit". The list refreshes when
the menu opens. Actions route through `ActionPresenter` like every other surface.
