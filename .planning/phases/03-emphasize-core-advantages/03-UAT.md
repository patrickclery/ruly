---
status: testing
phase: 03-emphasize-core-advantages
source: [03-VERIFICATION.md]
started: 2026-11-02T09:46:47Z
updated: 2026-11-02T09:46:47Z
---

## Current Test

number: 1
name: Site demo flow after WR-03 (deploy-mode question removed)
expected: |
  In the site's interactive terminal demo, for both project types, the flow goes straight from project type to the repo-name step and renders the generated output without errors.
awaiting: user response

## Tests

1. Site demo flow after WR-03 — walk the demo for both project types; confirm it reaches the repo-name step and renders. (pending)
2. Accept or revert review-fix scope deviations — site/app/layout.tsx, site/lib/generate-demo-data.ts, site/components/InteractiveTerminal.tsx were edited (plan forbade); hero install badge became an <a> with hover classes; footer span gained break-all. If accepted, add an overrides: entry to 03-VERIFICATION.md frontmatter. (pending)

## Summary

total: 2
passed: 0
issues: 0
pending: 2

## Gaps

None recorded yet.
