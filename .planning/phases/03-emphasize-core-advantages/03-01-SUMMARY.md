---
phase: 03-emphasize-core-advantages
plan: 01
subsystem: docs
tags: [readme, positioning, nextjs-site, claude-code-comparison]
status: complete

requires:
  - phase: 02-lean-out-native-duplication
    provides: 0.2.0 CLI surface (positional recipes, introspect RECIPE SOURCE...) that README examples now match
provides:
  - README `## Why ruly` section (five advantages) above Quick Install
  - README `## Ruly vs. native Claude Code` six-row table with code.claude.com docs links
  - README `## Reference` section holding the moved Subagents subtree
  - Site hero and feature cards rewritten around the same five advantages
  - 85% token figure marked self-reported, pending the Phase 6 benchmark
affects: [04-agents-md-output-target, 06-token-and-compliance-benchmark, 07-competitor-composition-audit]

actuals:
  tokens: 15772
  tasks: 3
  commits: 3
plan_head_before: 82b1db1dd5aa9412d8f7ea32cbb0aef0cc28a63d
plan_head_after: 4627801b5b87da1b394d3d5cbb6232eb6a4fc991

tech-stack:
  added: []
  patterns:
    - "Comparative claims about Claude Code use reference-style [docs][cc-*] links defined in the same section"

key-files:
  created: []
  modified:
    - README.md
    - site/app/page.tsx
    - site/components/FileTree.tsx
    - .claude/ruly-recipes-mcp-patterns.md

key-decisions:
  - "Ruly vs. native table concedes native subagent model: and skills: fields; ruly's edge is generating them per recipe with a fallback chain"
  - "Token cost row states no percentage; says savings are not yet independently benchmarked (D-06)"
  - "Subagents subtree moved verbatim under ## Reference; pointer sentence left before Recipe System"

patterns-established:
  - "Native Claude Code claims cite code.claude.com/docs/en pages and are dated (November 2026)"

requirements-completed: []

duration: 3min
completed: 2026-11-02
---

# Phase 3 Plan 01: Emphasize Core Advantages Summary

**README and landing page now lead with five verified advantages (recipes, `requires:` resolution, per-subagent recipe/model, `--sync` with `overrides:`, post-squash checks), contrasted with native Claude Code in a docs-cited table.**

## Performance

- **Duration:** ~3 min (wall clock as measured)
- **Started:** 2026-11-02T09:34:54Z
- **Completed:** 2026-11-02T09:37:37Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- `## Why ruly` (10 body lines) above Quick Install, linking to the comparison table.
- `## Ruly vs. native Claude Code`: six rows, every native cell links to code.claude.com docs (memory, path-specific rules, imports, symlinks, user-level rules, sub-agents).
- Site hero/cards rewritten (Recipes, Subagents, Sync and checks); tag/className/SVG sequence unchanged; build and lint exit 0 (lint fixed via `{"// "}` in FileTree.tsx).
- Stale 0.2.0 examples fixed (recipe switch, introspect signature/examples, glob bullet); Subagents reference moved under `## Reference` intact; README Prettier-clean.
- 85% figure marked self-reported, pending Phase 6; superlatives and the "no system dependencies" bullet removed.

## Task Commits

1. **Task 1 (tracer): Why ruly + site copy + lint fix** - `4139dfa` (docs)
2. **Task 2: Cited comparison table, claim cleanup** - `ef79c88` (docs)
3. **Task 3: Move Subagents reference, fix 0.2.0 examples** - `4627801` (docs)

## Files Created/Modified

- `README.md` - Why ruly, comparison table, Reference section, corrected examples, Prettier-formatted
- `site/app/page.tsx` - hero and feature-card copy only
- `site/components/FileTree.tsx` - render-identical `{"// "}` lint fix
- `.claude/ruly-recipes-mcp-patterns.md` - 85% lines marked self-reported / Phase 6

## Decisions Made

- `ruly stats` row wording: "token counts per file and in total" (verified in lib/ruly/operations/stats.rb) rather than "per recipe".
- Benefits bullet replaced with "Requirements: Ruby 3.3+ (with Bundler), and the `gh` CLI for GitHub sources".

## Deviations from Plan

None - plan executed exactly as written. Tracer gate: build and lint re-run end to end and passed before expansion.

## Issues Encountered

None. All Task 1-3 automated gates, the scope gate, build, lint and `bin/ruly version` (Ruly v0.2.0) pass.

## Follow-ups

- site/app/layout.tsx metadata still carries the old tagline (left unchanged; D-09 scopes copy changes to page.tsx).
- The demo (site/lib/generate-demo-data.ts, InteractiveTerminal.tsx) still uses `profiles:`, `profile:` and `gitignore:` keys plus override/merge/ghost modes, which ruly does not read.
- Phase 6 should replace the patterns-note 85% wording and the table's "not yet benchmarked" sentence with measured numbers.
- Phase 7 may add Ruler/rulesync rows.

## Next Phase Readiness

Positioning is in place for Phases 4-7; no blockers.

## Self-Check: PASSED

All four modified files exist; commits 4139dfa, ef79c88 and 4627801 are ancestors of HEAD.
