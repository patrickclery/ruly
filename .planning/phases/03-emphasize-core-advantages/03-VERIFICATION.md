---
phase: 03-emphasize-core-advantages
verified: 2026-11-02T18:30:00Z
status: passed
score: 6/6 must-haves verified
covered_files:
  - ".claude/ruly-recipes-mcp-patterns.md"
  - ".planning/phases/03-emphasize-core-advantages/03-01-PLAN.md"
  - ".planning/phases/03-emphasize-core-advantages/03-01-SUMMARY.md"
  - "README.md"
  - "site/app/layout.tsx"
  - "site/app/page.tsx"
  - "site/components/FileTree.tsx"
  - "site/components/InteractiveTerminal.tsx"
  - "site/lib/generate-demo-data.ts"
covered_digest: "v3:sha256:40fa0e3c21a94cfcf1c7348ea87b7ce88f13e8a629307c3021f414503396ef77"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "Review fixes stay inside the plan's file scope"
    reason: "User accepted in UAT 2026-11-02: edits to site/app/layout.tsx, site/lib/generate-demo-data.ts, site/components/InteractiveTerminal.tsx, the hero install badge <a> with hover classes, and footer break-all are a deliberate scope extension."
    accepted_by: "Patrick Clery"
    accepted_at: "2026-11-02"
re_verification:
  previous_status: human_needed
  previous_score: 6/6
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 3: Emphasize Core Advantages Verification Report

**Phase Goal:** Make ruly's verified advantages the headline (task-scoped recipes, `requires:` resolution with cycle detection, per-subagent recipe/model, `--sync` with per-machine overrides, post-squash checks) and rewrite README/site positioning against native `.claude/rules/`, `@imports` and symlink sharing.
**Verified:** 2026-11-02T18:30:00Z
**Status:** passed
**Re-verification:** Yes. The prior report went stale because phase 06 edited README.md and `.claude/ruly-recipes-mcp-patterns.md` (replaced the 85% claim with measured figures); UAT (03-UAT.md, 2/2 passed) has since resolved both human items.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `## Why ruly` (at most 15 body lines) above install, naming five advantages | VERIFIED | README.md:10, before `## Quick Install`; five bullets (recipes, `requires:`/circular chains, per-subagent recipe+model, `--sync`/`overrides:`, post-squash checks); links to the comparison section |
| 2 | `## Ruly vs. native Claude Code` table, 6 rows, native cells link code.claude.com | VERIFIED | README.md:92; the six required rows present; six `[cc-*]` definitions, all `https://code.claude.com/docs/en/...`; the `#ruly-vs-native-claude-code` anchor link from Why ruly is intact |
| 3 | Site hero and 3 cards state same advantages; lint and build exit 0 | VERIFIED | `npm --prefix site run lint` clean; `npm --prefix site run build` succeeds (static `/` and `/_not-found`). `site/app/page.tsx` hero (:18) and cards (:48, :66) carry recipes, `requires:`, per-subagent model, `--sync`/`overrides:`, checks. Tag/className deviations from review fixes are covered by the accepted override |
| 4 | No unqualified 85% claim outside `.planning` | VERIFIED | `git grep "85%"` outside `.planning` finds only an unrelated `similarity_threshold: 0.85` in `.claude/commands/ruly/compress.md`. The patterns file (:5, :156, :249) now states a measured "median 74.3%" scoped to "ruly's synthetic fixture corpus (not the WorkAxle rules)" and links `../docs/benchmarks.md`; README:100 gives 74.3% and 68.4% with the 63.0% no-recipe caveat and links `docs/benchmarks.md`. `docs/benchmarks.md` exists and its figures (74.3%, 68.4%, 63.0%) match. The qualification the truth demands (no unsupported headline number) still holds, now via a measured, linked, corpus-scoped figure rather than a "self-reported" marker |
| 5 | Subagents reference under `## Reference`, intact | VERIFIED | `## Reference` at README.md:984, `### Subagents` :988 with `####` subsections (Defining Subagents, MCP Server Propagation :1063, Agent File Format :1106, Model Specification :1138, Directory Structure, When to Use); pointer at :514 uses `](#subagents)` |
| 6 | README examples use only 0.2.0 flags | VERIFIED | `git grep` for `ruly import/analyze/mcp`, `--cache`, taskmaster, `squash --recipe/-r` in README.md returns nothing |

Score: 6/6 truths verified (0 behavior-unverified).

### Phase-06/07 supersessions (not regressions)

- Truth 4 and the "no new benchmark numbers" prohibition deferred numbers to Phase 6; Phase 6 published them in `docs/benchmarks.md`, linked from README and the patterns file. This is the planned hand-off, and the wording stays honest (synthetic corpus, 63.0% caveat).
- The "no Ruler/rulesync comparison" prohibition deferred that comparison to Phase 7; README.md:114 `## Ruly vs. Ruler and rulesync` is Phase 7 work (commit d26fb03), not a Phase 3 breach.

### Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No Ruler/rulesync comparison (Phase 3 scope) | Held, superseded by Phase 7 | Absent from site/ and from Phase 3's own sections; the README section is Phase 7's |
| No unqualified 85% / no new benchmark numbers | Held, superseded by Phase 6 | See truth 4 |
| Subagents subtree not deleted | Held | Truth 5 |
| Native per-subagent model not denied | Held | Table row acknowledges subagent `model:` and `skills:` |
| No TBD/FIXME/XXX debt markers | Held | Only hit is the `WA-XXXX` Jira placeholder in README:896, not a debt marker |
| No new tags/classNames; no edits to layout.tsx, site/lib, demo components | Overridden (accepted) | Review-fix edits accepted by Patrick Clery in UAT 2026-11-02; see `overrides:` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Site lints | `npm --prefix site run lint` | no errors | PASS |
| Site builds | `npm --prefix site run build` | static pages generated | PASS |
| Demo flow, both project types | Manual UAT (03-UAT.md test 1) | pass | PASS |

### Requirements Coverage

Phase declares no requirement IDs; no orphans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `README.md` | 96-103 | `prettier --check README.md` now fails: the comparison table's column widths no longer match after Phase 06 lengthened the "Token cost of includes" cell | Info | Formatting only; run `npx prettier --write README.md`. Content and links are correct |
| `site/lib/generate-demo-data.ts` | 12-77, 212, 305, 366 | Dead `profiles:`/override branches left after WR-03 | Info | Unreachable; accepted in UAT scope |

### Human Verification Required

None. Both prior items were resolved in 03-UAT.md (2/2 passed).

### Gaps Summary

No gaps. Phase 06's edits to README.md and the patterns file did not break any Phase 3 must-have. The only residual item is a cosmetic prettier realignment of the README table.

---

_Verified: 2026-11-02T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
