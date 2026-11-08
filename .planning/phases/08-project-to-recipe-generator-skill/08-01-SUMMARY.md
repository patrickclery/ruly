---
phase: 08-project-to-recipe-generator-skill
plan: 01
subsystem: skills
status: complete
tags: [skill, recipe, matching, validation]
requires: []
provides:
  - skills/recipe-from-project.md (URL-fetchable skill, name recipe-from-project)
  - fenced blocks evidence-check, exact-match, url-match, preflight, validate-recipe
affects:
  - 08-02 (ruly-tools recipe and rules repo sort commit)
  - 08-03 (push checkpoint and end-to-end URL verification)
tech-stack:
  added: []
  patterns:
    - Deterministic steps as fenced bash blocks with a first-line comment, extracted and run by gates
    - Stripped-body comparison using the FrontmatterParser split rule
    - Temp HOME with the clone linked as the mirror for dry-run validation
key-files:
  created:
    - skills/recipe-from-project.md
  modified: []
decisions:
  - Match order stays name first, then content, per CONTEXT; body-differs note covers the edited-body case
  - Step 5 runs the name check before stopping, so a no-match report says whether the default name is taken
  - Drafts list every entry in full, with no shorthand
metrics:
  duration: "Task 1 on 2026-11-04; Tasks 2-3, fix and session checks 2026-11-07 20:30-21:00 CST"
  completed: 2026-11-07
estimate:
  tokens: 70000
  tasks: 3
actuals:
  tokens: 5800
  tasks: 3
  commits: 4
plan_head_before: 113daf6afea165f132a2c47b32e4ec92e1b190cc
plan_head_after: 206e44db254f3dbbc6b3e9f1bf07419ca37de9a3
---

# Phase 08 Plan 01: recipe-from-project Skill Summary

A self-contained skill that inventories a project's squash output, matches it to the rules clone by name, body, substring and fetched URL, prunes to roots, drafts a labelled recipe, and on approval inserts, sorts, preflights and dry-runs it in the clone, leaving the change uncommitted.

## Tasks

| Task | Name | Commit |
| ---- | ---- | ------ |
| 1 | Tracer: generated skills through to a shown draft | 0b19fa6 |
| 2 | Every scan-list source, URL entries, pruning, unmatched report, stop on no match | 069647b |
| 3 | Approved write, sort, preflight, validation, report, remaining sections | 8f0901b |
| fix | Name collision on no match, drafts listed in full (from session checks) | 206e44d |

`actuals.tokens` is chars/4 over the one file changed (23185 bytes).

## Automated gates (all run against the final file)

- Task 1: frontmatter two keys; real squash under temp HOME, body equal; homelab skills=26 exact=26 none=0; evidence-check `evidence-ok` on homelab, `no-evidence` on the leftover folder.
- Task 2: this repo has 0 exact rows and `none` rows for exactly the three `.claude/commands` files; homelab 26/26 skills exact, `exact-rule`=8; URL fixture `self`=1, `exact-url`=1, `exact-url-rule`=1, `inferred-url`=1 after an edit; literal checks pass.
- Task 3: preflight prints exactly the six expected rows; validate-recipe gives `exit=0` with no findings for homelab and `exit=0` with a `File not found` finding for a bad path; rules clone clean; 15 headings and literals present; prettier clean; privacy gate clean; 08-01 commits touch only `skills/recipe-from-project.md`; `~/.config/ruly/recipes.yml` unchanged.

## Human checks (run headless per coordinator instruction)

Setup: the plan's "Session setup for human checks" block under the scratchpad (`ruly squash ruly-tools` in a temp cwd with temp HOME, a `git clone` of the rules repo as the copy). Each check ran `claude -p "/recipe-from-project <TARGET>\n\nUse the rules clone at <copy>." --add-dir <TARGET> --add-dir <copy> --output-format json` from the temp cwd with the real HOME, continuing with `--resume <session_id>` for follow-ups.

| Check | Observed | Result |
| ----- | -------- | ------ |
| Task 1 tracer, original session | User replied "approved"; the follow-up `git -C <copy> status --short` was **not run** (reboot wiped `/tmp`) | Session: approved by user. Status: not run |
| A: homelab | Skill loaded, path arrived through `$ARGUMENTS`; draft with 8 files, 25 skills, 2 subagents all exact; `raid-luks-install` pruned as agent-owned (26 total); reported generated from recipe `homelab`; name taken, asked for another; said nothing written; copy status empty | Pass (also covers the Task 1 status property) |
| Decline | "Nothing was written"; copy status empty | Pass |
| B: this repo | No match, three commands and `CLAUDE.md` reported, nothing written, status empty. First run did **not** flag `ruly` as taken; fixed in 206e44d, rerun flagged it | Pass after fix |
| C: no argument | Stopped with the no-evidence explanation, asked for a path, mentioned git recovery, 2 turns | Pass |
| D: agile | 6 frontmatter-reached skills pruned; 10 requires-reached rule files pruned (plan expected 4); `omit_command_prefix` offered with a labelled reason; nothing written. Draft used a brace shorthand for 10 commands; fixed in 206e44d (prose only, not re-run) | Pass on pruning and prefix; rule-file count differs from expectation (see Deviations) |
| D: core-solo | Three obra/superpowers URLs verbatim with commit pin, labelled exact (`exact-url`); nothing written | Pass |
| E: approve `draft-check` | Copy shows only ` M recipes.yml`; HEAD unchanged; `grep -c inferred` = 0; preflight and dry run reported clean; said uncommitted; real clone status empty | Pass |
| F: `draft-check-2` with `missing/nope.md` and `no-such-server` | Reported `missing-path` and `File not found` plus `unknown-mcp`, called it failing despite exit 0, offered to fix without reverting | Pass |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] No-match report omitted the name collision**
- **Found during:** headless check B
- **Issue:** Step 5 stops before Step 6's name check, so `ruly` was not flagged as taken.
- **Fix:** Step 5 now runs the name check and reports it.
- **Commit:** 206e44d

**2. [Rule 1 - Bug] Draft could use shorthand entries**
- **Found during:** headless check D (agile)
- **Fix:** Step 6 requires every entry in full. Not re-run after the fix.
- **Commit:** 206e44d

### Recorded differences

- **Task 2 gate 1 expected `exact-rule` = 7; observed 8.** The homelab recipe gained an eighth file on 2026-11-06 and the project was re-squashed that day; all 8 recipe files match. The rerun gate compares against the recipe's current file count.
- **agile pruned 10 rule files, not 4.** Step 4 drops any entry reachable through `requires:` from another matched entry, which also removes files the agile recipe lists redundantly. Consistent with the skill's rule, but not the planned count.
- **Observation, not fixed:** in check E, `yalphabetize -a` on the unsorted copy dropped one YAML comment and reflowed comments and blank lines (357-line diff). The skill reported this to the user. 08-02's pre-sort commit is where this belongs.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: skills/recipe-from-project.md
- FOUND: 0b19fa6, 069647b, 8f0901b, 206e44d (ancestors of HEAD)
