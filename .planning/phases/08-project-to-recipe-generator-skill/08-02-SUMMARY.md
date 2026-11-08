---
phase: 08-project-to-recipe-generator-skill
plan: 02
subsystem: docs
status: complete
tags: [readme, recipe, rules-repo]
requires:
  - 08-01 (skills/recipe-from-project.md)
provides:
  - README bullet /recipe-from-project and section "Drafting a Recipe From a Project"
  - rules repo sort commit 51e5fe8 (order only)
  - rules repo ruly-tools recipe commit 611a89e (4-line hunk)
affects:
  - 08-03 (push both repos, verify the URL fetch after main)
tech-stack:
  added: []
  patterns:
    - Sort commit checked as a same-multiset-of-lines change, not just parsed equality
key-files:
  created: []
  modified:
    - README.md
    - ~/github.com/patrickclery/rules/recipes.yml
decisions:
  - Sort commit restores the comment indents, trailing spaces and blank line that yalphabetize reflowed, so it reorders lines only
metrics:
  duration: "~15 min"
  completed: 2026-11-07
estimate:
  tokens: 30000
  tasks: 3
actuals:
  tokens: 3448
  tasks: 3
  commits: 1
plan_head_before: 695099bdc25a9116bc45df210c42ccbd40a4e5dd
plan_head_after: 90ab0c21777096570b7a267f7098a2a408db7eeb
---

# Phase 08 Plan 02: README Routes and ruly-tools Recipe Summary

README documents `/recipe-from-project` with both routes, the network note and the do-not-squash-here warning; the rules repo has an order-only sort commit followed by a 4-line `ruly-tools` recipe commit, both local and unpushed.

## Tasks

| Task | Name | Repo | Commit |
| ---- | ---- | ---- | ------ |
| 1 | README bullet and usage routes | ruly | 90ab0c2 |
| 2 | Sort recipes.yml in its own commit | rules | 51e5fe8 |
| 3 | Add ruly-tools recipe | rules | 611a89e |

`commits: 1` counts this repo only (ledger range). The two rules repo commits are listed above. `actuals.tokens` is chars/4 over the added/removed lines of all three commits (the sort's moved lines dominate).

## Gates

- Task 1: region check exit 0 (first bullet is the skill, all literals present, network note, no `.planning` link); README numstat `23 0`.
- Task 2: `sorted_exit=0 files=recipes.yml parsed_equal=true comments=153/153`. Extra check: sorted file and parent contain the same multiset of lines (`sort | diff` empty), numstat `151 151`.
- Task 3 gate 1: `sorted_exit=0 numstat=4 0 recipes.yml others_equal_and_entry_ok=true`.
- Task 3 gate 2: `state=pending rules_dirty=0`. Findings were exactly the one `Failed to fetch` for the URL and `squash failed: 1 required source(s) missing`. **Pending, verified after main in 08-03. Not a pass.**
- `git -C ~/github.com/patrickclery/rules log origin/main..main` lists 611a89e then 51e5fe8; status clean; nothing pushed in either repo. `~/.config/ruly/recipes.yml` unchanged. No commit touches `lib/`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] yalphabetize reflowed comments and whitespace in the sort**
- **Found during:** Task 2
- **Issue:** `yalphabetize -a` kept all 153 comments this time (no drop, unlike the copy in 08-01), but reindented four section comments (`Communications`, `PR & Merge`, `QA` to 6 spaces; `Corporate Advisor` to 4), added a trailing space to four `mcp_servers:` lines, and removed the blank line before the trailing top-level comment.
- **Fix:** Restored those lines by text edit before committing; `yalphabetize` still exits 0. The commit now reorders lines only.
- **Commit:** 51e5fe8 (rules repo)

### Recorded differences

- Rules repo baseline was `ee57bb4`, not the planned `a102dd8`; it was clean, on `main`, unsorted, with no `ruly-tools`, so the precondition held.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: README.md section and bullet
- FOUND: 90ab0c2 (ancestor of HEAD); 51e5fe8, 611a89e (ancestors of rules repo main)
