---
phase: 03-emphasize-core-advantages
reviewed: 2026-11-13T12:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - site/app/layout.tsx
  - site/app/page.tsx
findings:
  critical: 0
  warning: 0
  info: 4
  total: 4
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-11-13T12:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

This is an incremental re-review of the 483c4c2 delta (`site/app/layout.tsx`, `site/app/page.tsx`); the 8 findings of the 2026-11-02 report were closed earlier, in the previous 03-REVIEW-FIX.md.

This is iteration 2. It checks the three fix commits 8b21355, f39a067 and 13471bb (`git diff 250c5eb HEAD -- site/app/page.tsx`) against the previous report's WR-01, WR-02 and WR-03.

- **WR-01 (URL overflow): resolved.** The URL is now `<code className="font-mono text-green-400 break-all">` (`page.tsx:99`). In headless Chrome at 14px, a paragraph containing the URL span with `word-break: break-all` has `scrollWidth == clientWidth` at 181px, 224px and 295px, which are the md, 3-column and mobile card widths. Before the fix, `scrollWidth` was 357 at 224px.
- **WR-02 (data-loss warning): resolved.** The card now gives only the README's two routes: the URL goes into "that recipe's skills: list" for a project already built from a recipe, and `ruly-tools` is squashed in an empty directory. It also repeats the README.md:920 warning: squashing `ruly-tools` inside the project overwrites `CLAUDE.local.md` and empties `mcpServers` in `.mcp.json`. Each claim matches README "Drafting a Recipe From a Project" (README.md:900-922). The copy leaves out "even when the fetch fails" and the `overrides:` alternative, but neither omission makes a statement wrong. One remaining gap in the ruly-tools route is listed as IN-04 (Info).
- **WR-03 (no-recipe qualifier): resolved.** "Three fixture rules are in no recipe; without them the medians are 70.9% and 63.0%" (`page.tsx:84`) matches docs/benchmarks.md:9 and the "Files in no recipe" table (70.9% vs load-all, 63.0% vs native floor). The two figures are in the same order as the 74.3% / 68.4% pair before them. "A native layout's always-loaded set" matches the doc's definition of the native floor.
- `npx eslint app/page.tsx app/layout.tsx` and `npx tsc --noEmit` both exit 0.

`IN-01`, `IN-02` and `IN-03` were left out of the fix scope, and all three still apply. `IN-01` keeps its ID, with its evidence updated: the fix wrapped the URL, but the fix copy adds more bare tokens. `IN-04` is new.

## Narrative Findings (AI reviewer)

## Info

### IN-01: Config/CLI tokens rendered as bare prose, now mixed with one code span in the same paragraph (carried over, evidence updated)

**File:** `site/app/page.tsx:18`, `:75`, `:99`; `site/app/layout.tsx:18`
**Issue:** Several tokens are still plain text: `(-a agents)`, `-a claude-plugin`, `claude --plugin-dir`, `/RECIPE:RECIPE-rules` and `requires:`/`overrides:` in the hero and the plugin card. The WR-02 fix adds more bare tokens in `page.tsx:99`: `skills:`, `ruly-tools`, `CLAUDE.local.md`, `mcpServers`, `.mcp.json`, `ruly squash` and `/recipe-from-project`. In the same paragraph, the WR-01 fix renders the URL as a green monospace `<code>` span. The result is one code-styled token among about seven unstyled ones, which reads as inconsistent. Phrases like "empties mcpServers in .mcp.json" are harder to parse than they would be with the tokens marked.
**Fix:** Wrap each token in `<code className="font-mono text-green-400">…</code>`, which is the same class the URL span uses (`break-all` is needed only on the URL).

### IN-02: Site claims contradict the README comparison-table row they should match (carried over)

**File:** `site/app/layout.tsx:18`, `site/app/page.tsx:18`, `:75` (conflict at `README.md:126`, outside this review's scope)
**Issue:** The site says output goes to "Claude Code, AGENTS.md or a Claude Code plugin". README.md:126 (the "Agents" row) still says "3 targets, `claude`, `agents` (`AGENTS.md`) and `cursor`; skills, commands and subagents are written only for Claude Code." That row leaves out `claude-plugin` (0.4.0), and `AGENTS.md` does inline skills. The site is correct and the README row is stale.
**Fix:** Update README.md:126 to list `claude-plugin` as a fourth target, and note that `AGENTS.md` inlines skills.

### IN-03: Meta description is 219 characters (carried over)

**File:** `site/app/layout.tsx:18`
**Issue:** The description is still 219 characters long. Search results truncate at about 155-160 characters, so the "AGENTS.md or a Claude Code plugin" clause is the part that gets cut.
**Fix:** Shorten it, for example: "Recipes pick the rules, skills and commands each task needs from one shared rules repo, for Claude Code, AGENTS.md or a Claude Code plugin."

### IN-04: The card's ruly-tools route skips the two README steps it depends on

**File:** `site/app/page.tsx:99`
**Issue:** "For any other project, squash the ruly-tools recipe in an empty directory" presents `ruly-tools` as though it already exists, and the route ends there. README.md:907-918 adds two conditions the card does not mention:
1. `ruly-tools` is not shipped with the gem. It comes from the rules repo's `recipes.yml` through `ruly squash --sync`, or the user has to define it in `./.recipes.yml` or `~/.config/ruly/recipes.yml`. Otherwise the squash fails with "Recipe 'ruly-tools' not found" (`lib/ruly/services/recipe_loader.rb:250-252`).
2. Claude has to be started with `claude --add-dir <project> --add-dir <rules clone>`, and the project path has to be passed to the skill. The skill "defaults to the current folder", so a reader who follows the card literally runs it against the empty directory.

Neither step loses data. The first fails loudly and the second gives an empty draft, and the "How to run it" link covers both. The card's own instructions are still incomplete.
**Fix:** Point to the README for the setup instead of implying the route is complete, for example: "For any other project, squash the ruly-tools recipe in an empty directory and pass the skill the project path (see How to run it for defining ruly-tools and the --add-dir flags)."

---

_Reviewed: 2026-11-13T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
