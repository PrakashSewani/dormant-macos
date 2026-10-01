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
   and publishes the GitHub release with the `Dormant-v<version>.dmg` artifact (D-019). The DMG is
   the Release build (`xcodebuild -project Dormant.xcodeproj -scheme Dormant -configuration Release
   -destination 'platform=macOS' -derivedDataPath build build`) packaged by
   `Scripts/make-dmg.sh` (`create-dmg`, drag-to-Applications layout) into `build/`.
4. Verify: `gh run watch`, the release page, and a launch smoke of the downloaded DMG (mount,
   drag or `brew install --cask`, launch).
5. Promo site deploy (manual, only when the human asks): the site builds to `site/_site/`
   (`npm ci --include=dev && npm run build` in `site/`, D-009). Host: the GitHub Pages project
   site (`https://prakashsewani.github.io/dormant-macos/`), served from the `gh-pages` branch
   (one-time human setting: Pages → Deploy from branch → `gh-pages` / root). Publish:
   `git subtree push --prefix site/_site origin gh-pages`.
6. Publish to the Homebrew tap (D-010; after the release is verified):

   1. `gh release download v<version> -p "Dormant-v<version>.dmg" --dir /tmp/dormant-release`
   2. `shasum -a 256 /tmp/dormant-release/Dormant-v<version>.dmg`
   3. In [`PrakashSewani/homebrew-tap`](https://github.com/PrakashSewani/homebrew-tap): set
      `version "<version>"` and `sha256 "<the shasum>"` in `Casks/dormant.rb` (first release:
      create the file from the template below), commit `dormant <version>`, push to `main`.
   4. Verify: `brew update && brew install --cask PrakashSewani/tap/dormant`, launch smoke
      (approve "Open Anyway", enable the Finder extension). On an existing install:
      `brew upgrade --cask dormant`. Uninstall safety check: `brew uninstall --cask dormant`
      must leave `~/.dormant` (registry + archives) untouched.

Cask template — `Casks/dormant.rb` in `PrakashSewani/homebrew-tap` (D-010: never `zap`
`~/.dormant`, it holds the project registry and the archive store = user source code):

```ruby
cask "dormant" do
  version "<version>"
  sha256 "<sha256>"

  url "https://github.com/PrakashSewani/dormant-macos/releases/download/v#{version}/Dormant-v#{version}.dmg"
  name "Dormant"
  desc "Put idle macOS project workspaces to sleep: clean, archive and restore them safely"
  homepage "https://prakashsewani.github.io/dormant-macos/"

  depends_on macos: ">= :tahoe"

  app "Dormant.app"

  caveats <<~EOS
    Dormant is ad-hoc signed (no Apple Developer Program — docs/decisions.md D-001/D-010).
    On first launch macOS blocks it: open System Settings → Privacy & Security, click
    "Open Anyway", then launch Dormant again.
    Then enable the Finder extension in System Settings → Extensions (Finder Extensions)
    and relaunch Finder for the "Dormant ▸" context menu.
  EOS

  zap trash: "~/Library/Preferences/com.dormant.Dormant.plist"
end
```

Rollback / yank: `gh release delete v<version> --yes` (keep or delete the tag with
`git tag -d v<version> && git push origin :refs/tags/v<version>`), and in
`PrakashSewani/homebrew-tap` `git revert` the `dormant <version>` commit so installs fall back to
the previous release. Fix forward with a new patch version. There is no store listing to pull and
nothing runs on Dormant servers (local-first).
