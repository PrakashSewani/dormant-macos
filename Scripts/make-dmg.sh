#!/bin/bash
set -euo pipefail

# Builds build/Dormant-v<version>.dmg from the Release build (D-019).
# Expects build/Build/Products/Release/Dormant.app and create-dmg
# (brew install create-dmg). The version comes from MARKETING_VERSION
# in project.yml — the version source of truth.

version=$(sed -n 's/.*MARKETING_VERSION: "\([0-9][0-9.]*\)".*/\1/p' project.yml | head -1)
app="build/Build/Products/Release/Dormant.app"
out="build/Dormant-v${version}.dmg"

if [ -z "$version" ]; then
  echo "could not read MARKETING_VERSION from project.yml" >&2
  exit 1
fi
if [ ! -d "$app" ]; then
  echo "missing $app — run the Release build first" >&2
  exit 1
fi
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not found — brew install create-dmg" >&2
  exit 1
fi

rm -f "$out"
create-dmg \
  --volname "Dormant ${version}" \
  --window-pos 200 120 \
  --window-size 600 320 \
  --icon-size 100 \
  --icon "Dormant.app" 150 130 \
  --app-drop-link 430 130 \
  "$out" \
  "$app"
echo "wrote $out"
