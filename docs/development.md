# Development

Every command below was run on this machine (2026-09-26).

## Prerequisites

- macOS 26+ (developed on macOS 27.0, Apple silicon; deployment target 26.0 since D-018).
- Xcode 27.0 (build 27A266a) — full Xcode, not just the Command Line Tools.
- Homebrew; XcodeGen 2.46.0 (`brew install xcodegen`).
- Node.js 18+ (developed on Node 24.19.0) — for the promo site only.

## Setup

```bash
brew install xcodegen
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
npm ci --include=dev --prefix site
```

The Xcode project is generated from `project.yml` — `Dormant.xcodeproj` is not committed; the
check command regenerates it.

## Commands

| Command | What it does |
|---|---|
| `Scripts/check.sh` | lint → `xcodegen generate` → build → test. The one command that must pass before anything is "done". |
| `xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' test` | Tests only (step 4 of the check). |
| `xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' -derivedDataPath build build` | Debug build of `Dormant.app` into `build/`. |
| `open build/Build/Products/Debug/Dormant.app` | Run the app (menu bar item). Quit with `osascript -e 'quit app "Dormant"'`. |
| `xcodebuild -project Dormant.xcodeproj -scheme Dormant -configuration Release -destination 'platform=macOS' -derivedDataPath build build` | Release build — the input to the release DMG. |
| `Scripts/make-dmg.sh` | Build `Dormant-v<version>.dmg` from the Release build with the drag-to-Applications layout (the artifact `release.yml` ships, D-019). |
| `npm run build --prefix site` | Build the promo site into `site/_site/` (also step 5 of the check). |
| `npm start --prefix site` | Eleventy dev server with live reload at <http://localhost:8080/>. |
| `swift Scripts/render-icons.swift` | Regenerate every icon size (app icon set, site favicons) from the mark drawn in the script (D-013). |

Raw `xcodebuild` commands assume `xcode-select` points at Xcode (see Setup). `Scripts/check.sh`
locates `Xcode.app` itself when it doesn't.

## Environment

No env vars, no secrets (`site/package.json` and `site/eleventy.config.js` are build config).
`Scripts/check.sh` exports
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` when `xcode-select` still points at the
Command Line Tools. The app keeps its data in `~/.dormant/` (created on first use).

## Releases and deploys

Create release PRs from `dev` to `main` and apply exactly one release label:
`release:patch`, `release:minor`, or `release:major`. After merge, release automation runs only
from `main`, updates `MARKETING_VERSION` in `project.yml` and `CHANGELOG.md`, creates a matching
`v<version>` tag, and publishes a GitHub release. Merges without a release label do not publish a
release (`docs/decisions.md` D-007). Product deploys stay manual; the promo site auto-deploys
from merges into `dev` via Cloudflare Workers Builds (D-025); see
[`.commandcode/skills/ship-release/SKILL.md`](../.commandcode/skills/ship-release/SKILL.md) for
the project-specific procedure.

Implemented by `.github/workflows/release.yml` (reworked 2026-09-26 from the tag trigger to the
labeled-merge flow): on merge it bumps `MARKETING_VERSION`, promotes the `[Unreleased]`
changelog section, commits, tags `v<version>`, and publishes the GitHub release with
`Dormant-v<version>.dmg` (D-019). An unlabeled or multiply-labeled merge publishes nothing.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `xcodebuild` says "requires Xcode, but active developer directory … CommandLineTools" | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| "You have not agreed to the Xcode license agreements" | `sudo xcodebuild -license accept` |
| `xcodegen: command not found` | `brew install xcodegen` |
| `node: command not found` when running the check | Install Node.js 18+ (the site build is step 5 of the check). |
| `eleventy: command not found` when building the site | Your npm env omits dev dependencies (`NODE_ENV=production`); install with `npm ci --include=dev --prefix site`. |
| The "Dormant ▸" Finder menu doesn't appear (anywhere) | First confirm the extension is registered: `pluginkit -mAvvv -p com.apple.FinderSync` must list `com.dormant.Dormant.Finder`. If it doesn't, `pkd` rejected it — read why with `log show --last 10m --predicate 'processImagePath CONTAINS "pkd"' --info` (a "plug-ins must be sandboxed" line means the appex lost its App Sandbox entitlement, see D-011). If it is listed, launch the app once, then enable the extension in System Settings → Extensions (Finder Extensions) and relaunch Finder. Ad-hoc-signed local builds may need a one-time approval. Note: Finder Sync shows the submenu inside monitored directories (`directoryURLs` is `/`, so anywhere in the file system), not on Desktop icons while Finder's Desktop is iCloud-synced. |
