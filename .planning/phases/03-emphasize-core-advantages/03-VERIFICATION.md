---
phase: 03-emphasize-core-advantages
verified: 2026-11-02T11:30:00Z
status: human_needed
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
covered_digest: "v3:sha256:91f2a8bb11e6cae1050d44d5b621880196aed4a8709029d5c455eabc5fa3ede1"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 6/6
  gaps_closed: []
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Open the site demo (npm --prefix site run dev), pick Single repo and Multi-repo in turn, and walk to the end."
    expected: "Project type leads straight to the repo-name step (no deploy-mode question); generated output renders without errors and uses the merge wording."
    why_human: "Code-review fix WR-03 removed the q-mode step from InteractiveTerminal.tsx; the interactive flow is client-side state that lint/build cannot exercise."
  - test: "Decide whether the review-round edits to files the plan prohibited (site/app/layout.tsx, InteractiveTerminal.tsx, site/lib/generate-demo-data.ts) and the new hero install badge element (div changed to a link with hover classes) are accepted."
    expected: "Accept as a deliberate scope extension (add an overrides: entry) or request revert."
    why_human: "The plan prohibitions (no layout.tsx/site/lib/demo edits; no new tags/classNames) were deliberately overridden by the code-review fixes WR-03 and IN-03. This is a judgment-tier prohibition; it is flagged, not silently passed."
---

# Phase 3: Emphasize Core Advantages Verification Report

**Phase Goal:** Make ruly's verified advantages the headline (task-scoped recipes, `requires:` resolution with cycle detection, per-subagent recipe/model, `--sync` with per-machine overrides, post-squash checks) and rewrite README/site positioning against native `.claude/rules/`, `@imports` and symlink sharing.
**Verified:** 2026-11-02T11:30:00Z
**Status:** human_needed
**Re-verification:** Yes, after code-review fixes (WR-01..04, IN-01, IN-03 site part, IN-04 Phase 6 part)

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `## Why ruly` (at most 15 body lines) above install, naming five advantages | VERIFIED | README.md:10, before `## Quick Install` (:22); five bullets; the checks bullet now says "every squash that writes files (not `--dry-run`)", which matches `cli.rb` (`Checks.run_all` is in `post_squash`, dry-run returns early at :76) |
| 2 | `## Ruly vs. native Claude Code` table, 6 rows, native cells link code.claude.com | VERIFIED | README.md:92; six rows; six `[cc-*]` definitions all `https://code.claude.com/docs/en/...`; `prettier --check README.md` passes after the IN-01 realignment |
| 3 | Site hero and 3 cards state same advantages; lint and build exit 0 | VERIFIED | Re-run now: `npm --prefix site run lint` clean, `npm --prefix site run build` succeeds (4 static pages). Hero/cards carry the five advantages; Recipes card now says "ruly stats lists any circular chains" (WR-04), which matches `operations/stats.rb`. See prohibition note below on tag/className changes |
| 4 | No unqualified 85% claim outside `.planning` | VERIFIED | `.claude/ruly-recipes-mcp-patterns.md` lines 5, 156, 249 all say "self-reported; unverified until an independent benchmark measures it"; no other token-claim 85% in README/site |
| 5 | Subagents reference under `## Reference`, intact | VERIFIED | `## Reference` at README.md:823 with `### Subagents` and all `####` subsections (MCP Server Propagation, Agent File Format, Model Specification, etc.); pointer at :475 uses `](#subagents)` |
| 6 | README examples use only 0.2.0 flags | VERIFIED | `git grep` for `ruly import/analyze/mcp`, `--cache`, taskmaster, `squash --recipe/-r` in README.md returns nothing; patterns file WR-01 fix replaced `squash --recipe` with `squash <recipe>` |

Score: 6/6 truths verified (0 behavior-unverified).

### Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No Ruler/rulesync comparison | Held | `git grep -niw 'ruler\|rulesync'` over README.md, site/app, site/components, site/lib: empty |
| No unqualified 85% / no new benchmark numbers | Held | See truth 4; table says savings are "not independently benchmarked yet" |
| Subagents subtree not deleted | Held | See truth 5 |
| Native per-subagent model not denied | Held | Table cell acknowledges subagent `model:` and `skills:` |
| No marketing superlatives | Held | Superlative grep over README.md, site/app, site/components: empty |
| No TBD/FIXME/XXX debt markers | Held | Only hit is the `WA-XXXX` Jira ticket placeholder in an unchanged README command description, not a debt marker |
| No new pages/components/tags/classNames/SVGs | FLAGGED (judgment) | Review fix IN-03 replaced the hero `<div>` badge with an `<a>` carrying `cursor-pointer ... hover:brightness-110 transition duration-200`, and the footer span gained `break-all`. Copy and link behavior justified by IN-03, but it is a tag/className change the plan forbade |
| No edits to layout.tsx, site/lib, demo components; CLAUDE.md/lib/rules untouched | FLAGGED (judgment) | Review fix WR-03 edited `site/app/layout.tsx` (metadata text), `site/components/InteractiveTerminal.tsx` (removed q-mode step) and `site/lib/generate-demo-data.ts` (two strings). `lib/`, `rules/`, `CLAUDE.md` untouched. Gemfile.lock is modified and unstaged (pre-existing) |

These two flagged items are deliberate, documented review-round scope extensions (03-REVIEW-FIX.md), not accidents, but they contradict the written prohibitions and need an explicit human decision or an `overrides:` entry.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Site lints | `npm --prefix site run lint` | no errors | PASS |
| Site builds | `npm --prefix site run build` | 4/4 static pages generated | PASS |
| Markdown formatting | `npx --no-install prettier --check README.md .claude/ruly-recipes-mcp-patterns.md` | all files pass | PASS |
| Dry-run excludes checks | `cli.rb` squash returns at the dry-run branch before `post_squash` | confirmed by reading | PASS |

### Requirements Coverage

Phase declares no requirement IDs; no orphans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `site/lib/generate-demo-data.ts` | 12-77, 212, 305, 366 | Demo still generates `profiles:` YAML and override/ghost branches that ruly does not read (dead branches left by WR-03; `profiles:` pre-existing) | Warning | Demo output is stale relative to the new hero. Dead branches are unreachable now (deployMode fixed to `merge`). Not blocking the headline positioning |

### Human Verification Required

#### 1. Demo flow after q-mode removal

**Test:** Run the site dev server, complete the demo for both project types.
**Expected:** Project type goes directly to the repo-name step; no mode question; output renders.
**Why human:** Client-side interactive state, not covered by lint/build.

#### 2. Accept or revert review-round scope extension

**Test:** Review the layout.tsx, InteractiveTerminal.tsx, generate-demo-data.ts edits and the hero badge `<a>`.
**Expected:** Accept (add `overrides:` entry naming the prohibitions) or request revert.
**Why human:** Plan prohibitions were deliberately overridden by review fixes.

### Gaps Summary

No failing truths. Phase goal is achieved in the code; the status is `human_needed` only because of the demo-flow change and the two flagged prohibition deviations introduced by the review-fix round.

---

_Verified: 2026-11-02T11:30:00Z_
_Verifier: Claude (gsd-verifier)_
