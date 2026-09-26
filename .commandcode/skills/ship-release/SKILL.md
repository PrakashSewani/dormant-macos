---
name: ship-release
description: Explain the automated release path and perform manual product/site deployments when asked. The release workflow is filled in at bootstrap time.
license: MIT
metadata:
  template: template-app-plus-site
  version: "1"
---

# Release and deploy

## Rules (always)

- **Release trigger:** only a pull request merged into `main` can start release-related workflows.
  Work on `dev` never publishes a release.
- **Release selection:** a release PR has exactly one `release:patch`, `release:minor`, or
  `release:major` label. A merge without one of these labels does not publish a release.
- **Version source of truth:** the chosen stack's manifest. The workflow applies the labeled bump,
  creates a `v<version>` tag matching the manifest, and publishes a GitHub release.
- **Deployments are manual.** Give the user exact, copy-pasteable commands; never deploy without
  being asked.
- **Record the real procedure here** when the stack is chosen (see "Procedure" below), including
  the automated release workflow, artifact handling, and failure path — how to yank a bad release.

## Procedure

Recorded at bootstrap (2026-09-26); updated 2026-09-26 for the labeled-release policy
(`docs/decisions.md` D-007). Stack: Swift/Xcode, XcodeGen (`docs/decisions.md` D-001).

**Version source of truth:** `MARKETING_VERSION` in `project.yml`. A release tag is `v<version>`
and must match it exactly.

Release (cut only when the human asks):

1. Land the release content on `dev` through feature-branch PRs; `Scripts/check.sh` must pass.
2. Open a release PR from `dev` to `main` and apply exactly one label: `release:patch`,
   `release:minor`, or `release:major`.
3. On merge, the release workflow (`.github/workflows/release.yml`) applies the labeled bump to
   `MARKETING_VERSION`, updates `CHANGELOG.md`, commits on `main`, creates the `v<version>` tag,
   and publishes the GitHub release with the `Dormant-v<version>.zip` artifact. The zip is the
   Release build — `xcodebuild -project Dormant.xcodeproj -scheme Dormant -configuration Release
   -destination 'platform=macOS' -derivedDataPath build build` then
   `cd build/Build/Products/Release && zip -r "Dormant-v<version>.zip" Dormant.app` (both verified
   locally 2026-09-26).
4. Verify: `gh run watch`, the release page, and a launch smoke of the downloaded zip.
5. Promo site deploy: filled in at phase 3, when the site has a host (the site deploys
   independently of the product).

Rollback / yank: `gh release delete v<version> --yes` (keep or delete the tag with
`git tag -d v<version> && git push origin :refs/tags/v<version>`), fix forward with a new patch
version. There is no store listing to pull and nothing runs on Dormant servers (local-first).
