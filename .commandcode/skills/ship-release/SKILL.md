---
name: ship-release
description: Release and deploy this project. Use when the user asks to release, ship, publish, or deploy. Deploys are manual by policy; this skill is filled in with the project's real commands at bootstrap time.
license: MIT
metadata:
  template: dormant-macos
  version: "1"
---

# Ship a release

## Rules (always)

- **Version source of truth:** the manifest of the chosen stack (e.g. `package.json`,
  `Cargo.toml`). A release tag is `v<version>` and must match it exactly.
- **Deploys are manual.** Give the user exact, copy-pasteable commands; never wire an
  auto-deploy pipeline, and never deploy without being asked.
- **CI builds artifacts on tags; publishing and deploying are deliberate human steps.**
- **Record the real procedure here** when the stack is chosen (see "Procedure" below), including
  the failure path — how to yank a bad release.

## Procedure

Recorded at bootstrap (2026-09-26). Stack: Swift/Xcode, XcodeGen (`docs/decisions.md` D-001).

**Version source of truth:** `MARKETING_VERSION` in `project.yml`. A release tag is `v<version>`
and must match it exactly.

Release (manual — run only when the human asks):

1. Bump `MARKETING_VERSION` in `project.yml`; add the `CHANGELOG.md` entry (on `dev`, via PR —
   D-002).
2. Run `Scripts/check.sh` (docs/development.md) and the Release build:
   `xcodebuild -project Dormant.xcodeproj -scheme Dormant -configuration Release -destination 'platform=macOS' -derivedDataPath build build`
   then `cd build/Build/Products/Release && zip -r "Dormant-v<version>.zip" Dormant.app`
   (both verified locally 2026-09-26; CI runs the same steps via `.github/workflows/release.yml`).
3. Merge `dev` → `main` via a PR (checks must pass), then tag on `main` only:
   `git checkout main && git pull && git tag v<version> && git push origin main --tags`
4. Watch CI: `gh run watch`. The `Release` workflow uploads `Dormant-v<version>.zip` as the
   workflow artifact (build only — no publishing).
5. Publish deliberately: `gh release create v<version> build/Build/Products/Release/Dormant-v<version>.zip --title "Dormant v<version>" --notes-file CHANGELOG.md`
   — only when the human asks.
6. Promo site deploy: filled in at phase 3, when the site has a host (the site deploys
   independently of the product).

Rollback / yank: `gh release delete v<version> --yes` (keep or delete the tag with
`git tag -d v<version> && git push origin :refs/tags/v<version>`), fix forward with a new patch
version. There is no store listing to pull and nothing runs on Dormant servers (local-first).
