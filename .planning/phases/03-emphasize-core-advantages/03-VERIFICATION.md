---
phase: 03-emphasize-core-advantages
verified: 2026-11-13T13:00:00Z
status: human_needed
score: 5/6 must-haves verified
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
covered_digest: "v3:sha256:14de9da1bad04ecdd9003de12d16e0bce49cb70a9c2eb8f385ea6cb9326584c3"
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
  regressions:
    - "Truth 3 (clause: page tags and classNames unchanged) no longer holds as written: commit 483c4c2 added three cards with new SVGs and a <code> element. Not covered by the accepted override; owner decision requested."
human_verification:
  - test: "Decide whether the three cards added to site/app/page.tsx in 483c4c2 (AGENTS.md and plugin output, Fixture benchmark, Draft a recipe from a project), their SVG icons and the <code className=\"font-mono text-green-400 break-all\"> element are an accepted scope extension of Phase 3's D-10 (copy changes only)"
    expected: "Either accept (add an overrides: entry, see Gaps Summary) or reply revert, which makes truth 3 FAILED and routes to gap closure"
    why_human: "The plan prohibited new tags, classNames and SVGs. The additions are deliberate and serve Phases 4, 5, 6 and 8, but only the owner can waive a Phase 3 prohibition. The accepted override names layout.tsx, generate-demo-data.ts, InteractiveTerminal.tsx, the hero badge and the footer, and does not cover these additions."
---

# Phase 3: Emphasize Core Advantages Verification Report

**Phase Goal:** Make ruly's verified advantages the headline: task-scoped recipe composition, `requires:` dependency resolution with cycle detection, per-subagent recipe/model selection, multi-machine `--sync` with per-machine overrides, and post-squash checks. Rewrite README/site positioning against native `.claude/rules/` (path-only scoping), `@imports` (no token savings), and symlink sharing limits.
**Verified:** 2026-11-13T13:00:00Z
**Status:** human_needed
**Re-verification:** Yes. The prior report went stale because `site/app/layout.tsx` and `site/app/page.tsx` changed after b3a098c: commit 483c4c2 (AGENTS.md/plugin copy, fixture benchmark card, recipe-from-project card) and the review fixes 8b21355, f39a067, 13471bb. `git diff b3a098c HEAD -- site README.md docs .claude` shows only those two site files changed; README.md, docs/benchmarks.md and `.claude/` are unchanged since the last report. Every truth was re-checked against the current files.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `## Why ruly` (at most 15 body lines) above install, naming five advantages | VERIFIED | README.md:10, before `## 🚀 Quick Install` (:22). Seven non-blank body lines: intro, five bullets (task-scoped recipes, `requires:` with circular chains via `ruly stats`, a recipe and model per subagent, `--sync` with `overrides:`, post-squash checks) and the comparison pointer. The `#ruly-vs-native-claude-code` link resolves to the heading at :92 |
| 2 | `## Ruly vs. native Claude Code` table, 6 rows, native cells link code.claude.com | VERIFIED | README.md:92. Rows at :98-103: Per-task selection, Dependency resolution, Token cost of includes, Cross-machine sharing, Per-subagent model, Post-squash checks. Six `[cc-*]` definitions (:105-110), all `https://code.claude.com/docs/en/...`; every native cell has a `[docs][cc-*]` link. The native Per-subagent cell acknowledges the subagent `model:` field |
| 3 | Site hero and cards state the same advantages as Why ruly; page tags and classNames unchanged; lint and build exit 0 | UNCERTAIN (owner decision) | Advantages: VERIFIED. Hero (page.tsx:17-18) and the Recipes, Subagents and Sync-and-checks cards (:57-69) name recipes, `requires:`, circular chains, per-subagent recipe and model, `--sync` with `overrides:`, and post-squash checks. Lint and build: VERIFIED (re-run, both exit 0). "Tags and classNames unchanged": NOT HELD. `git diff b3a098c HEAD -- site/app/page.tsx` adds three cards (6 `card-glow` blocks now vs 3), three new `<svg>` icons (6 vs 3), and a `<code className="font-mono text-green-400 break-all">` element. The plan prohibited this (D-10, copy changes only) and the accepted override does not name it. See Gaps Summary |
| 4 | No unqualified 85% claim outside `.planning` | VERIFIED | `git grep "85%" -- . ':!.planning'` returns only `similarity_threshold: 0.85 # 85% similar` in `.claude/commands/ruly/compress.md:253`, unrelated. The new site benchmark card uses 74.3% / 68.4% with the 70.9% / 63.0% no-recipe-rules medians and a "synthetic fixture, not a real rules repo" qualifier; every figure matches docs/benchmarks.md (:7, :9, :32, :40-42, :50-52). README.md:100 carries the same figures |
| 5 | Subagents reference under `## Reference`, intact | VERIFIED | `## Reference` at README.md:1008, `### Subagents` :1012, with `####` subsections Defining Subagents :1016, MCP Server Propagation :1087, Agent File Format :1130, Model Specification :1162, Directory Structure :1214, When to Use :1234 and the later ones. Pointer at :514 uses `](#subagents)`. README.md is unchanged since the last report |
| 6 | README examples use only 0.2.0 flags | VERIFIED | `git grep -n -E "ruly (import\|analyze\|mcp)\|--cache\|taskmaster\|squash (--recipe\|-r )" -- README.md` returns nothing. `bin/ruly help squash` lists `-a ... (claude, cursor, agents, claude-plugin)` and the output-file help, matching the new site copy. README.md is unchanged |

Score: 5/6 truths verified, 1 awaiting owner decision (0 behavior-unverified).

### Effect of the site delta on the Phase 3 positioning

The five advantages remain the headline. The hero keeps its advantages sentence and appends one sentence on `-a agents` and `-a claude-plugin`; the three advantage cards are untouched and the new cards follow them. The new claims were checked against the README and code:

| Site claim | Source | Result |
|------------|--------|--------|
| `-a agents` writes AGENTS.md and skips commands, subagents, hooks, MCP servers | README.md:746-760 (`AGENTS.md target skips Claude-only parts: commands, subagents, ...`) | Matches |
| `-a claude-plugin` packages skills, commands, agents, hooks, MCP servers for `claude --plugin-dir`; rules ship as skill `/RECIPE:RECIPE-rules` | README.md:202, :780-810; `lib/ruly/services/claude_plugin.rb`; `bin/ruly help squash` lists the target | Matches |
| Skill is not installed with the gem, squash fetches it and needs the network | README.md:902 | Matches |
| Two routes (recipe `skills:` list, `ruly-tools` in an empty directory) and the data-loss warning | README.md:904-922 | Matches; the card omits two setup steps (IN-04) |
| Benchmark medians and the synthetic-fixture caveat | docs/benchmarks.md | Matches |

### Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No Ruler/rulesync comparison on the site or in Phase 3 scope | Held on the site | `git grep -i "ruler\|rulesync" -- site` returns nothing. The README section (:114) is Phase 7's |
| No unqualified 85% / no unmeasured numbers | Held, superseded by Phase 6 | Truth 4; the site numbers are Phase 6's measured figures with their caveats |
| Subagents subtree not deleted | Held | Truth 5 |
| Native per-subagent model not denied | Held | README table row acknowledges `model:` and `skills:` |
| No marketing superlatives | Held | `git grep -i` for best / revolution / powerful / seamless / blazing / unparalleled over `site/app` returns nothing |
| No TBD/FIXME/XXX debt markers | Held | `git grep -E "TBD\|FIXME\|XXX" -- site README.md docs` hits only the `WA-XXXX` Jira placeholder at README.md:897, not a debt marker |
| No new pages, components, tags, classNames or SVGs; copy changes only (D-10) | NOT HELD for 483c4c2; unresolved | Three new cards, three new SVGs, a new `<code>` element and its classes in `site/app/page.tsx`. Not covered by the accepted override. Owner decision requested |
| No edits to layout.tsx, site/lib, demo components | Overridden (accepted) for the 2026-11-02 edits | `site/app/layout.tsx` was edited again (meta description only). The accepted override names layout.tsx, so I treated this edit as inside it; if you read the override as limited to the 2026-11-02 edits, this one needs confirming too |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Site lints | `npm --prefix site run lint` | exit 0, no output | PASS |
| Site builds | `npm --prefix site run build` | 4 static pages generated; `/` and `/_not-found` | PASS |
| 85% claim | `git grep "85%" -- . ':!.planning'` | only the unrelated compress.md similarity threshold | PASS |
| Stale flags | `git grep -E "ruly (import\|analyze\|mcp)\|--cache\|taskmaster\|squash (--recipe\|-r )" -- README.md` | no matches | PASS |
| Site `-a` targets exist | `bin/ruly help squash` | `-a ... (claude, cursor, agents, claude-plugin)` | PASS |

### Requirements Coverage

The plan declares `requirements: []` and ROADMAP lists Requirements as TBD for Phase 3. REQUIREMENTS.md maps no ID to Phase 3. No orphans.

### UAT Checks (03-UAT.md)

| Check | Still holds? | Reasoning |
|-------|--------------|-----------|
| 1. Demo flow after WR-03 (project type goes straight to repo-name step) | Yes | The site delta touches only `site/app/page.tsx` and `site/app/layout.tsx`. `DemoSection`, `InteractiveTerminal.tsx` and `generate-demo-data.ts` are unchanged since the UAT, and the `<DemoSection />` call in page.tsx is untouched. Lint and build exit 0. The only layout effect is on the feature grid below the demo (3 cards became 6 in the same `md:grid-cols-3` grid), which does not touch the demo |
| 2. Accept review-fix scope deviations | The acceptance stands, but it does not extend to the new cards | The 2026-11-02 acceptance named five specific edits. None covers new cards, SVGs or the `<code>` element, which did not exist then. The layout.tsx change is a further edit to a file the acceptance names. See the human verification item |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `site/app/page.tsx` | 18, 75, 99; `layout.tsx:18` | IN-01: config and CLI tokens (`-a agents`, `requires:`, `skills:`, `mcpServers`, ...) are bare prose beside one `<code>` URL | Info | Readability only. No must-have depends on styling |
| `README.md` | 126 | IN-02: the Agents row of the Ruler/rulesync table says "3 targets" and omits `claude-plugin` | Info | Sits in Phase 7's comparison section, outside every Phase 3 truth. The site is correct; the README row is stale |
| `site/app/layout.tsx` | 18 | IN-03: meta description is 219 characters; the AGENTS.md / plugin clause is the part search results truncate | Info | SEO only |
| `site/app/page.tsx` | 99 | IN-04: the `ruly-tools` route omits that the recipe comes from `--sync` or a `.recipes.yml` entry and that Claude needs `--add-dir <project>` | Info | Incomplete but not wrong; fails loudly or gives an empty draft, and "How to run it" links to the full steps |
| `README.md` | 96-103 | `prettier --check README.md` fails on the comparison table width | Info | Formatting only (carried over) |
| `site/lib/generate-demo-data.ts` | 12-77, 212, 305, 366 | Dead `profiles:` / override branches left after WR-03 | Info | Unreachable; accepted in UAT scope (carried over) |

None of IN-01 to IN-04 breaks a Phase 3 truth: IN-01, IN-03 and IN-04 concern the added cards, not the positioning must-haves, and IN-02 is in Phase 7's table.

### Human Verification Required

#### 1. Accept or reject the new site cards (D-10 deviation)

**Test:** Read `git diff b3a098c HEAD -- site/app/page.tsx` and decide whether the three added cards, their SVG icons and the `<code>` element are an accepted extension of Phase 3's "copy changes only" rule.
**Expected:** Accept (add the override below) or reply "revert".
**Why human:** Only the owner can waive a plan prohibition. The additions look intentional (commit 483c4c2 is a deliberate feature commit that surfaces Phases 4, 5, 6 and 8) and nothing in them contradicts the Phase 3 positioning.

### Gaps Summary

No code gap and no broken advantage claim: the README truths are intact and unchanged, the site still leads with the five advantages, and lint and build pass. The one open item is a scope question, not a defect. Truth 3 required the site's tags and classNames to stay unchanged, and 483c4c2 added new cards, SVGs and a `<code>` element. **This looks intentional.** To accept it, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "Site hero and cards state the same advantages as Why ruly; page tags and classNames unchanged"
    reason: "Later phases (4, 5, 6, 8) needed AGENTS.md/plugin output, the fixture benchmark and recipe-from-project on the landing page; three cards, their SVGs and one <code> element were added in 483c4c2 and fixed in 8b21355, f39a067, 13471bb"
    accepted_by: "{name}"
    accepted_at: "{ISO timestamp}"
```

With that override the status becomes `passed` (6/6, overrides_applied 2). If the owner rejects the additions, truth 3 becomes FAILED and the status `gaps_found`.

---

_Verified: 2026-11-13T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
