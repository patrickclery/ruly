---
phase: 03-emphasize-core-advantages
verified: 2026-11-08T12:00:00Z
status: passed
score: 6/6 must-haves verified
covered_files:
  - ".claude/ruly-recipes-mcp-patterns.md"
  - ".planning/phases/03-emphasize-core-advantages/03-01-PLAN.md"
  - ".planning/phases/03-emphasize-core-advantages/03-01-SUMMARY.md"
  - "README.md"
  - "docs/benchmarks.md"
  - "site/app/layout.tsx"
  - "site/app/page.tsx"
  - "site/components/FileTree.tsx"
  - "site/components/InteractiveTerminal.tsx"
  - "site/lib/generate-demo-data.ts"
covered_digest: "v3:sha256:878ab6e556fc3bd0d98b57f431e1895ec5173a56634bb19b4af00867b369507a"
behavior_unverified: 0
overrides_applied: 1
overrides:
  - must_have: "Review fixes stay inside the plan's file scope"
    reason: "User accepted in UAT 2026-11-02: edits to site/app/layout.tsx, site/lib/generate-demo-data.ts, site/components/InteractiveTerminal.tsx, the hero install badge <a> with hover classes, and footer break-all are a deliberate scope extension."
    accepted_by: "Patrick Clery"
    accepted_at: "2026-11-02"
re_verification:
  previous_status: passed
  previous_score: 6/6
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 3: Emphasize Core Advantages Verification Report

**Phase Goal:** Make ruly's verified advantages the headline: task-scoped recipe composition, `requires:` dependency resolution with cycle detection, per-subagent recipe/model selection, multi-machine `--sync` with per-machine overrides, and post-squash checks. Rewrite README/site positioning against native `.claude/rules/` (path-only scoping), `@imports` (no token savings), and symlink sharing limits.
**Verified:** 2026-11-08T12:00:00Z
**Status:** passed
**Re-verification:** Yes. The prior report went stale because README.md changed again: Phase 08 (PRs #5 and #6) added the `/recipe-from-project` bullet under "Available Ruly Commands" and the recipe-from-project lines (README.md:894-916). Every Phase 3 must-have was re-checked against the current tree; none is affected. `docs/benchmarks.md` was added to the covered files because truth 4 depends on it.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `## Why ruly` (at most 15 body lines) above install, naming five advantages | VERIFIED | README.md:10, before `## 🚀 Quick Install` (:22). Body is 7 non-blank lines: intro, five bullets (task-scoped recipes, `requires:` with circular chains via `ruly stats`, a recipe and model per subagent, `--sync` with `overrides:`, post-squash checks) and the comparison pointer. The `#ruly-vs-native-claude-code` link resolves to the heading at :92 |
| 2 | `## Ruly vs. native Claude Code` table, 6 rows, native cells link code.claude.com | VERIFIED | README.md:92. Rows: Per-task selection, Dependency resolution, Token cost of includes, Cross-machine sharing, Per-subagent model, Post-squash checks. Six `[cc-*]` definitions (:105-110), all `https://code.claude.com/docs/en/...`; every native cell carries a `[docs][cc-*]` link |
| 3 | Site hero and 3 cards state same advantages; lint and build exit 0 | VERIFIED | Re-run today: `npm --prefix site run lint` exits 0 with no output; `npm --prefix site run build` succeeds (static `/` and `/_not-found`). No site or `.claude` file changed since the prior report (`git log` shows only older commits). Tag/className deviations are covered by the accepted override |
| 4 | No unqualified 85% claim outside `.planning` | VERIFIED | `git grep "85%"` outside `.planning` returns only `similarity_threshold: 0.85 # 85% similar` in `.claude/commands/ruly/compress.md:253`, unrelated. README.md:100 gives 74.3% and 68.4% with the 63.0% no-recipe caveat and links `docs/benchmarks.md`; those figures match `docs/benchmarks.md` (lines 7, 9, 32, 40) |
| 5 | Subagents reference under `## Reference`, intact | VERIFIED | `## Reference` at README.md:1008, `### Subagents` :1012, with `####` subsections Defining Subagents :1016, MCP Server Propagation :1087, Agent File Format :1130, Model Specification :1162, Directory Structure :1214, When to Use :1234. Pointer at :514 uses `](#subagents)`. Phase 08 line shifts did not disturb the subtree |
| 6 | README examples use only 0.2.0 flags | VERIFIED | `git grep` for `ruly import/analyze/mcp`, `--cache`, taskmaster and `squash --recipe/-r` in README.md returns nothing. `bin/ruly help squash`/`clean`/`introspect` confirm the flags README uses (`-o`, `-a`, `-c`, `-d`, `--deepclean`, `--dry-run`, `--sync`, `--strict`, `--relative`, `-d DESCRIPTION`) and the `introspect RECIPE SOURCE...` signature. The Phase 08 additions introduce no `ruly` flags |

Score: 6/6 truths verified (0 behavior-unverified).

### Effect of the Phase 08 README change

The new `/recipe-from-project` bullet (:894) and recipe-from-project section (:896-916) sit in the Slash Commands/Examples area. They add no `ruly` command or flag, do not touch Why ruly, the comparison table or the Reference/Subagents section, and name no Ruler/rulesync comparison. No Phase 3 truth is affected. The earlier human-verified items (03-UAT.md, 2/2 passed) concern site files that have not changed since, so they stand as they were.

### Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No Ruler/rulesync comparison in Phase 3 scope | Held, superseded by Phase 7 | `git grep -i "ruler\|rulesync" -- site` finds nothing; README.md:114 is Phase 7's section (d26fb03) |
| No unqualified 85% / no unmeasured numbers | Held, superseded by Phase 6 | Truth 4 |
| Subagents subtree not deleted | Held | Truth 5 |
| Native per-subagent model not denied | Held | Table row acknowledges subagent `model:` and `skills:` |
| No TBD/FIXME/XXX debt markers | Held | Only hit is the `WA-XXXX` Jira placeholder at README.md:897, not a debt marker |
| No new tags/classNames; no edits to layout.tsx, site/lib, demo components | Overridden (accepted) | Accepted by Patrick Clery in UAT 2026-11-02; see `overrides:` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Site lints | `npm --prefix site run lint` | exit 0, no errors | PASS |
| Site builds | `npm --prefix site run build` | static pages generated | PASS |
| README flags exist in 0.2.0 | `bin/ruly help squash`, `clean`, `introspect` | flags present | PASS |
| Demo flow, both project types | Manual UAT (03-UAT.md test 1) | pass (unchanged site files) | PASS |

### Requirements Coverage

Phase declares no requirement IDs (ROADMAP: `TBD`); no orphans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `README.md` | 96-103 | `prettier --check README.md` still fails: comparison-table column widths do not match the long "Token cost of includes" cell | Info | Formatting only; `npx prettier --write README.md` fixes it. Content and links are correct |
| `site/lib/generate-demo-data.ts` | 12-77, 212, 305, 366 | Dead `profiles:`/override branches left after WR-03 | Info | Unreachable; accepted in UAT scope |

### Human Verification Required

None. Both items were resolved in 03-UAT.md (2/2 passed) and the files they cover are unchanged.

### Gaps Summary

No gaps. Phase 08's README additions did not break any Phase 3 must-have.

---

_Verified: 2026-11-08T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
