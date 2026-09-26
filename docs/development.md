# Development

Every command below was run on this machine (2026-09-26).

## Prerequisites

- macOS 14+ (developed on macOS 27.0, Apple silicon).
- Xcode 27.0 (build 27A266a) — full Xcode, not just the Command Line Tools.
- Homebrew; XcodeGen 2.46.0 (`brew install xcodegen`).
- Python 3 (for the site preview only — it ships with macOS).

## Setup

```bash
brew install xcodegen
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
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
| `xcodebuild -project Dormant.xcodeproj -scheme Dormant -configuration Release -destination 'platform=macOS' -derivedDataPath build build` | Release build — the artifact `release.yml` zips. |
| `python3 -m http.server 8931 -d site` | Preview the promo site at <http://127.0.0.1:8931/>. |

Raw `xcodebuild` commands assume `xcode-select` points at Xcode (see Setup). `Scripts/check.sh`
locates `Xcode.app` itself when it doesn't.

## Environment

No env vars, no secrets, no config files. `Scripts/check.sh` exports
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` when `xcode-select` still points at the
Command Line Tools. The app keeps its data in `~/.dormant/` (created on first use, phase 2).

## Releases and deploys

Manual by policy — the exact commands live in
[`.commandcode/skills/ship-release/SKILL.md`](../.commandcode/skills/ship-release/SKILL.md).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `xcodebuild` says "requires Xcode, but active developer directory … CommandLineTools" | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| "You have not agreed to the Xcode license agreements" | `sudo xcodebuild -license accept` |
| `xcodegen: command not found` | `brew install xcodegen` |
| The "Dormant ▸" Finder menu doesn't appear | Launch the app once, then enable the extension in System Settings → Extensions (Finder Extensions) and relaunch Finder. Ad-hoc-signed local builds may need a one-time approval. |
