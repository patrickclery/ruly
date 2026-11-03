---
phase: 03-emphasize-core-advantages
reviewed: 2026-11-02T09:41:01Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - site/app/page.tsx
  - site/components/FileTree.tsx
  - README.md
  - .claude/ruly-recipes-mcp-patterns.md
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-11-02T09:41:01Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Docs/positioning phase. Verified clean:

- `eslint` on both changed TSX files exits 0, and `tsc --noEmit` exits 0. The FileTree `{"// "}` fix renders the same text as before.
- Every `ruly ...` example in README.md is valid against `bin/ruly help <cmd>` (0.2.0). No `-r` or `--recipe` is left, and the introspect docs and examples match `introspect RECIPE SOURCE...` with `-d/-o/--dry-run/--relative`.
- All internal anchors resolve to exactly one heading: `#ruly-vs-native-claude-code`, `#subagents` and `#sharing-recipes-across-machines` (twice).
- The Subagents subtree moved without losing content. The only differences from `8734d26~4` are `ruly squash -r full` changed to `ruly squash full`, Prettier table alignment and one blank line.
- The scoped files say nothing about Ruler or rulesync, so they make no superiority claims against them.
- The README claims about ruly match the code: stats cycle detection in `operations/stats.rb`, the two checks in `checks.rb`, the subagent > recipe > `inherit` model order in `subagent_processor.rb:267`, and `--strict`/`--sync` in squash help. The native-Claude-Code cells match the doc quotes recorded in 03-01-PLAN.md.

The issues are in the parts the phase only partly touched. The auto-imported patterns file still has a broken command and contradictory path rules. The site metadata and demo still carry the old "three modes" positioning. One site card overstates when circular `requires:` chains are reported.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Patterns file (auto-imported into CLAUDE.md) still instructs a command that fails on 0.2.0

**File:** `.claude/ruly-recipes-mcp-patterns.md:246`, `:252`
**Issue:** `ruly squash --recipe workaxle-testing` fails with `Unknown switches "--recipe"` (verified: the CLI sets `check_unknown_options!` at `lib/ruly/cli.rb:21`). CLAUDE.md:23 `@`-imports this file, so every agent session gets told to run it. The phase edited this file and had a "fix 0.2.0 command examples" goal, but it missed this line. Line 252 says `mise install ruby` updates the installed ruly, which it does not: it installs a Ruby version.
**Fix:**
```bash
# Squash a recipe for testing (run from temp directory)
cd $(mktemp -d)
ruly squash workaxle-testing
```
Replace `mise install ruby` with the project's actual reinstall step (for example `gem build ruly.gemspec && gem install ./ruly-*.gem`, or whatever the README install path is).

### WR-02: Patterns file gives contradictory path rules to agents

**File:** `.claude/ruly-recipes-mcp-patterns.md:21-23` vs `:178-183`; examples at `:38-44`, `:105-125`, `:175`
**Issue:** Section 1 marks machine-specific absolute paths as WRONG and repo-relative paths as CORRECT. Anti-pattern 3 says relative paths are WRONG and "Must use absolute paths". The Directory vs File and Complete Example blocks use `/Users/patrick/Projects/...` absolute paths. These are macOS paths, and this machine is Linux under `/home/patrick/github.com/...`. An agent following this file can write either form, and both are labelled wrong somewhere.
**Fix:** Delete anti-pattern 3. Convert the example `files:` entries to repo-relative paths (`workaxle/core.md`, `bug/`, ...) so they match section 1 and the README's "Sharing Recipes Across Machines".

### WR-03: Site metadata and demo still carry the positioning this phase removed

**File:** `site/app/layout.tsx:16-18`; `site/components/InteractiveTerminal.tsx:93-96,192-222` (rendered by `site/app/page.tsx:34`)
**Issue:** The new hero says "Compose the rules each task needs from one shared rules repo." The page `<title>`/description still say "Bring your own rules, skills, and agents to anywhere Claude is installed", which is the old h1 word for word. Search results and link previews will show the old message. The interactive demo directly under the hero still asks "How do you want to deploy your rules?" and offers Override / Merge / Ghost. The "Three Modes" card that explained those terms was removed (page.tsx:59-63), so the demo now uses undefined terms the site no longer explains.
**Fix:** Update `metadata` in `layout.tsx` to the new hero line and subtitle. Then either relabel the demo's deploy-mode step with the real flags (`--home-override`, `--git-ignore`/`--git-exclude`) plus a one-line explanation, or remove that step.

### WR-04: Site Recipes card says squash reports circular `requires:` chains, but only `ruly stats` does

**File:** `site/app/page.tsx:45`
**Issue:** "Dependencies declared with requires: are resolved and included once, and circular chains are reported." In the squash path, a cycle is silently deduplicated by the processed-file Set. `Checks.run_all` (`lib/ruly/checks.rb:12-27`) runs only AmbiguousLinks and DuplicateSkillRequires. Cycle detection exists only in `Operations::Stats#find_circular_dependencies` (`operations/stats.rb:124`). Cycles also do not appear on the console; they are written to `stats.md`, and `display_result` prints only the orphan count. The README is accurate ("`ruly stats` reports circular chains"), but the site card is not.
**Fix:** "...resolved and included once, and `ruly stats` lists any circular chains."

## Info

### IN-01: "Checks after every squash" is not true for `--dry-run`

**File:** `README.md:18`, `README.md:103`, `site/app/page.tsx:15`, `site/app/page.tsx:63`
**Issue:** `squash --dry-run` returns before `post_squash` (`lib/ruly/cli.rb:76-84`), so no checks run.
**Fix:** "Every squash that writes output checks for..." Alternatively, run `Checks.run_all` in the dry-run branch too.

### IN-02: Config tokens rendered as bare prose on the site

**File:** `site/app/page.tsx:15`, `:45`, `:54`, `:63`
**Issue:** `requires:`, `overrides:`, `ruly squash --sync`, `.claude/agents/` and `inherit` render as plain text, giving copy like "with per-machine overrides:." and "requires: pulls in". Without code styling the colons read as punctuation errors.
**Fix:** Wrap them in `<code className="font-mono text-green-400">…</code>`, as is done for the `gem install ruly` badge.

### IN-03: Install story contradicts itself

**File:** `README.md:127`, `README.md:129`; `site/app/page.tsx:9`, `:79`
**Issue:** The README says "No gem installation required" and installs by curl/clone, but the site hero badge and footer say `gem install ruly`. The new "Requirements" line is also listed under "Benefits" with a ✅.
**Fix:** Pick one install path, or document both. Move Requirements out of the Benefits list.

### IN-04: Internal planning jargon and a leftover overclaim in a session-loaded context file

**File:** `.claude/ruly-recipes-mcp-patterns.md:5`, `:156`, `:257-258`
**Issue:** "Phase 6 token benchmark" refers to `.planning/` and means nothing to an agent reading this file. Line 257 still sits under a "Key Achievements" heading. Line 258, "Conditional loading based on file patterns", contradicts the no-glob rule in the same file. README.md:105 also says native behavior is "quoted" from the docs, but most cells are paraphrases.
**Fix:** Change the qualifier to "(self-reported; not yet benchmarked)". Rename the heading to "Reported results" and drop "file patterns". In the README, say "summarized from" instead of "quoted from".

---

_Reviewed: 2026-11-02T09:41:01Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
