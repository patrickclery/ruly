---
phase: 03-emphasize-core-advantages
fixed_at: 2026-11-13T00:00:00Z
review_path: .planning/phases/03-emphasize-core-advantages/03-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 3: Code Review Fix Report

**Fixed at:** 2026-11-13
**Source review:** .planning/phases/03-emphasize-core-advantages/03-REVIEW.md (reviewed 2026-11-13T09:12:23Z)
**Iteration:** 1

This report replaces the earlier report for the 2026-11-02 review. Finding IDs below refer to the 2026-11-13 review only.

**Summary:**
- Findings in scope: 3 (WR-01, WR-02, WR-03; fix_scope critical_warning)
- Fixed: 3
- Skipped: 0 in scope (IN-01, IN-02, IN-03 out of scope)

## Fixed Issues

### WR-01: Raw skill URL overflows the "Draft a recipe from a project" card

**Files modified:** `site/app/page.tsx`
**Commit:** 8b21355
**Applied fix:** Wrapped the skill URL in `<code className="font-mono text-green-400 break-all">` so it wraps inside the card at every breakpoint.

### WR-02: Recipe-from-project card tells users to squash the skill into "a recipe" without the README's data-loss warning

**Files modified:** `site/app/page.tsx`
**Commit:** f39a067
**Applied fix:** Replaced "list URL under a recipe's skills:" with the README's two routes (add the URL to the skills: of the recipe a project is already built from, or squash ruly-tools in an empty directory) and added the README warning: do not squash ruly-tools inside the project you want to scan, since that squash overwrites CLAUDE.local.md and empties mcpServers in .mcp.json.

### WR-03: Benchmark card drops the "rules in no recipe" qualifier that docs/benchmarks.md attaches to the same medians

**Files modified:** `site/app/page.tsx`
**Commit:** 13471bb
**Applied fix:** Added "Three fixture rules are in no recipe; without them the medians are 70.9% and 63.0%." after the 74.3% / 68.4% medians, matching docs/benchmarks.md.

## Skipped Issues

### IN-01: New copy adds more config/CLI tokens as bare prose

**File:** `site/app/page.tsx:18`
**Reason:** out of scope (Info finding; fix_scope critical_warning)
**Original issue:** CLI/config tokens rendered as plain prose instead of code spans.

### IN-02: New site claims contradict the README comparison-table row they should match

**File:** `README.md:126`
**Reason:** out of scope (Info finding; fix_scope critical_warning)
**Original issue:** README "Agents" row omits the claude-plugin target and says AGENTS.md does not carry skills.

### IN-03: Meta description is 219 characters

**File:** `site/app/layout.tsx:18`
**Reason:** out of scope (Info finding; fix_scope critical_warning)
**Original issue:** Description exceeds the ~155-160 character search-result limit.

## Verification

Fixes were edited and committed in an isolated worktree (no node_modules), then fast-forwarded onto `gsd/phase-06-subscription-only`. The gates ran in the main checkout after the fast-forward: `npx eslint app` exit 0 and `npx tsc --noEmit` exit 0 (in `site/`).

---

_Fixed: 2026-11-13_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
