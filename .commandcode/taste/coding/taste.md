# Coding

## Design principles for tools that touch user data

- Safety first: data safety ranks above disk-space or performance gains. Never silently delete or
  discard anything (especially uncommitted work); preview destructive operations with an
  itemized summary (names, sizes, total reclaim) and confirm before running; prefer reversible
  operations; when file classification or project structure is uncertain, leave files alone
  rather than guess. Confidence: 0.85
- Local-first by default: no required cloud service, account, telemetry, or vendor backend;
  user data and git repositories stay under the user's control. Confidence: 0.8
- Prefer intelligent/heuristic detection (e.g. ecosystem-aware classification driven by detected
  manifests) over a single hardcoded list where reasonable. Confidence: 0.7
- Keep distribution concerns (code signing, notarization, certificates, App Store submission)
  explicitly out of initial builds — defer them so they don't complicate implementation. Local
  ad-hoc-signed builds are fine for development on the user's own machine. Confidence: 0.8
