---
phase: 03-emphasize-core-advantages
reviewed: 2026-11-13T09:12:23Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - site/app/layout.tsx
  - site/app/page.tsx
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-11-13T09:12:23Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

This is an incremental re-review of the 483c4c2 delta (`site/app/layout.tsx`, `site/app/page.tsx`); the 8 findings of the 2026-11-02 report were closed in 03-REVIEW-FIX.md.

Verified clean:

- `eslint app/page.tsx app/layout.tsx` and `tsc --noEmit` both exit 0.
- AGENTS.md card and hero: `-a agents` writes `AGENTS.md`, skips commands, subagents, hooks and MCP servers (README "AGENTS.md Output", CHANGELOG 0.3.0). `-a claude-plugin` packages skills, commands, agents, hooks and MCP servers for `claude --plugin-dir`, and the rules ship as `/RECIPE:RECIPE-rules` (README "Claude Code Plugin Output", CHANGELOG 0.4.0). Both shipped in 0.3.0/0.4.0, and `VERSION` is 0.4.0.
- "Every squash that writes files runs checks" still holds for the new targets. `write_agents_md` and `write_claude_plugin` both call `run_checks` (`lib/ruly/cli.rb:408`, `:511`). Dry-run still returns first.
- Benchmark card: 74.3% (vs load-all median), 68.4% (vs native floor median), five recipes and `cl100k_base` all match docs/benchmarks.md, and the card labels them as synthetic-fixture figures.
- Links resolve. `docs/benchmarks.md` and `skills/recipe-from-project.md` exist on `origin/main`, and `#drafting-a-recipe-from-a-project` matches exactly one README heading.
- "Not installed with the gem" is correct. `ruly.gemspec` `spec.files` does not include `skills/`.

Remaining problems: the new recipe-from-project card has a layout overflow, and it leaves out the README's data-loss warning. The benchmark card also drops a qualifier that docs/benchmarks.md places next to the same numbers.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Raw skill URL overflows the "Draft a recipe from a project" card

**File:** `site/app/page.tsx:99`
**Issue:** The full URL `https://github.com/patrickclery/ruly/blob/main/skills/recipe-from-project.md` is plain prose with no wrap opportunity. In headless Chrome at text-sm, a 224px box (the card's content width at the `max-w-4xl` 3-column layout) gives `scrollWidth` 357 against `clientWidth` 224. At the `md` breakpoint the content width is about 181px, and in the single-column mobile layout about 295px. Both are narrower than the URL, so the text spills past the card's border at every breakpoint. The footer already guards its long command with `break-all` (`page.tsx:115`), but the card does not.
**Fix:** Render the URL as a wrapping code span (or a link), for example:
```tsx
list <code className="font-mono text-green-400 break-all">https://github.com/patrickclery/ruly/blob/main/skills/recipe-from-project.md</code> under a recipe&apos;s skills:
```
Alternatively, add `break-words` / `[overflow-wrap:anywhere]` to the card's `<p>`.

### WR-02: Recipe-from-project card tells users to squash the skill into "a recipe" without the README's data-loss warning

**File:** `site/app/page.tsx:99`
**Issue:** The card says "list [URL] under a recipe's skills: and ruly squash fetches it". README "Drafting a Recipe From a Project" (README.md:902-922) allows only two routes: add the URL to *the project's own* recipe, or squash `ruly-tools` in an *empty* directory. It also warns: "Do not squash `ruly-tools` inside the project you want to scan. Squashing there overwrites `CLAUDE.local.md` and empties `mcpServers` in `.mcp.json`, even when the fetch fails, which destroys the files the skill reads." A reader who follows the card (any recipe, squashed where they want to use the skill, which is naturally the project to scan) can wipe the project's `CLAUDE.local.md` and MCP server config. This is the data the skill is meant to read. The "How to run it" link does not offset an instruction that, as written, is unsafe.
**Fix:** Narrow the instruction and carry the warning, for example: "...list [URL] under the project's own recipe's skills:, or squash the ruly-tools recipe in an empty directory. Do not squash another recipe inside the project you want to scan; that overwrites its CLAUDE.local.md and .mcp.json servers." Alternatively, drop the how-to sentence and keep only the "How to run it" link.

### WR-03: Benchmark card drops the "rules in no recipe" qualifier that docs/benchmarks.md attaches to the same medians

**File:** `site/app/page.tsx:84`
**Issue:** The card quotes 74.3% (vs load-all) and 68.4% (vs native floor). docs/benchmarks.md states the qualifier in the paragraph right after those headline numbers, and again under Limitations. Three always-loaded fixture rules (1,175 tokens, 14.5% of the native floor) are in no recipe, so they inflate every reduction. Without them the medians are 70.9% and 63.0%. The docs also say the native floor/ceiling "bracket native cost rather than pin it". The card's only caveat is "describe the synthetic fixture", so a reader takes 68.4% as the saving against a native setup. In the source, that figure is an upper-leaning number. For a page whose figures must match the benchmark doc, leaving out the doc's own adjacent qualifier is an overclaim.
**Fix:** Add the bounded figures, for example: "...a median 74.3% smaller than loading every rule and 68.4% smaller than a native layout's always-loaded set (70.9% and 63.0% without three fixture rules that no recipe includes)."

## Info

### IN-01: New copy adds more config/CLI tokens as bare prose (carry-over of prior IN-02)

**File:** `site/app/page.tsx:18`, `:75`, `:99`; `site/app/layout.tsx:18`
**Issue:** Prior IN-02 was marked out of scope in 03-REVIEW-FIX.md, and the delta makes it worse. `(-a agents)`, `-a claude-plugin`, `claude --plugin-dir`, `/RECIPE:RECIPE-rules`, `skills:` and a raw URL are all rendered as plain text, which gives copy like "under a recipe's skills: and ruly squash fetches it".
**Fix:** Wrap the tokens in `<code className="font-mono text-green-400">…</code>`. This also fixes WR-01.

### IN-02: New site claims contradict the README comparison-table row they should match

**File:** `site/app/layout.tsx:18`, `site/app/page.tsx:18`, `:75` (conflict at `README.md:126`, outside this review's scope)
**Issue:** The site now says output goes to "Claude Code, AGENTS.md or a Claude Code plugin". README.md:126 (Ruler/rulesync table, "Agents" row) still says "3 targets, `claude`, `agents` (`AGENTS.md`) and `cursor`; skills, commands and subagents are written only for Claude Code". That row leaves out `claude-plugin` (0.4.0), and `AGENTS.md` does inline skills. The site is right and the README row is stale, so a reader who checks the site against the README finds a contradiction.
**Fix:** Update README.md:126 to list `claude-plugin` as a fourth target, and note that `AGENTS.md` inlines skills.

### IN-03: Meta description is 219 characters

**File:** `site/app/layout.tsx:18`
**Issue:** The appended sentence makes the description 219 characters long. Search results truncate at about 155-160 characters, so the new "AGENTS.md or a Claude Code plugin" clause is the part that gets cut.
**Fix:** Shorten it, for example: "Recipes pick the rules, skills and commands each task needs from one shared rules repo, for Claude Code, AGENTS.md or a Claude Code plugin."

---

_Reviewed: 2026-11-13T09:12:23Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
