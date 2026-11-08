---
phase: 08-project-to-recipe-generator-skill
plan: 03
subsystem: release
status: complete
tags: [push, pr, verification, rules-repo]
requires:
  - 08-01 (skills/recipe-from-project.md)
  - 08-02 (README routes, rules repo ruly-tools commits 51e5fe8 and 611a89e)
provides:
  - skills/recipe-from-project.md and README.md on main of patrickclery/ruly (PR #5, merge 0d91b71)
  - rules repo main pushed with the ruly-tools recipe (ee57bb4..611a89e)
  - URL verified end to end through the validator, Route 2 and Route 1
affects:
  - Phase 08 verification (no deferral row; end-to-end checks ran)
tech-stack:
  added: []
  patterns:
    - Temp git worktree from origin/main for a cherry-pick PR, so this checkout never switches branches
key-files:
  created: []
  modified: []
decisions:
  - "Task 1: separate-pr, rules-push yes, merge. Chosen by the orchestrator under the user's standing instruction (2026-11-07): \"I have given you bypass permissions. You shouldn't have to ask me to do these. just do them\". The user did not type the option id."
  - PR #5 merged with a merge commit (gh pr merge --merge), keeping the five cherry-picked commits
  - Session checks used the URL-fetched skill under a temp HOME, not `ruly squash ruly-tools --sync` with the real HOME, so ~/.config/ruly/ stays untouched
metrics:
  duration: "~4 min wall clock (2026-11-08T03:04Z to 03:08Z UTC)"
  completed: 2026-11-07
estimate:
  tokens: 35000
  tasks: 3
actuals:
  tokens: 2200
  tasks: 3
  commits: 0
plan_head_before: a9fda50118d803459cd1f23ab98e910f245e5846
plan_head_after: a9fda50118d803459cd1f23ab98e910f245e5846
---

# Phase 08 Plan 03: Push to main and End-to-End URL Verification Summary

The skill reached `main` of patrickclery/ruly through PR #5, which holds only the five cherry-picked commits. The real URL then passed the validator, Route 2 and Route 1. The rules repo was pushed only after that, in the right order, and two headless sessions with the URL-fetched skill behaved as expected.

## Tasks

| Task | Name | Result | Commit |
| ---- | ---- | ------ | ------ |
| 1 | Decide route and rules push | `separate-pr, rules-push yes`, plus merge | none (decision) |
| 2 | Take the route to main | PR #5 opened and merged; prints `on-main` | ruly main 0d91b71 (merge of 800414a, 9c367f1, 709573b, 4a7386d, ccdc425) |
| 3 | Verify URL, push rules | 4/4 gates pass; rules pushed | rules main 611a89e (pushed, not new) |

`commits: 0` is the ledger range in this checkout before the docs commit. Nothing in this checkout needed a code commit: the code went to `main` by the PR, and the rules commits came from 08-02. `actuals.tokens` is the size of this SUMMARY and the PR body, at chars/4.

## Task 1 evidence (read-only, run before any push)

- Branch `gsd/phase-06-subscription-only`; `origin/main...HEAD` = `0 21`; 21 commits ahead, not 11 as at planning (08-01 and 08-02 work and docs added since). Not `main`, so `branch-pr` stayed a valid option.
- Commits: 0b19fa6, 069647b, 8f0901b, 206e44d (skill), 90ab0c2 (README).
- `ls-remote` for the branch: empty. Open PRs for the branch: none.
- Status: only the pre-existing `.planning/config.json`, `Gemfile.lock` and untracked `.planning/` files.
- Rules repo unpushed: 611a89e, 51e5fe8. `origin/main` = 2911706.
- Decision: `separate-pr, rules-push yes`, with merge. The orchestrator chose this under the user's standing instruction (2026-11-07): "I have given you bypass permissions. You shouldn't have to ask me to do these. just do them". The user did not type the option id.

## Task 2

- Each of the five commits touches only `skills/recipe-from-project.md` or `README.md`.
- Temp worktree at origin/main (scratchpad), branch `gsd/08-recipe-from-project`. The cherry-picks applied cleanly. `diff --name-only origin/main HEAD` showed exactly `README.md` and `skills/recipe-from-project.md`, and both match this checkout byte for byte.
- Pushed the branch without force. Opened https://github.com/patrickclery/ruly/pull/5, whose file list is the same two paths, then merged it with `gh pr merge 5 --merge` (merge 0d91b71).
- Verify printed `on-main`. The worktree was removed and `git worktree list` shows only this checkout. This checkout is still on `gsd/phase-06-subscription-only`.

## Task 3 gates

Precondition: the `gh api ...?ref=main` fetch exits 0.

| Gate | Output | Result |
| ---- | ------ | ------ |
| 1 Validator from rules clone | `fetch=0 cmp=0 exit0=1 findings=0 skill_line=1 rules_dirty=0` | Pass |
| 2 Route 2 | `route2_squash=0 body_equal=true local_md_bytes=0 evidence=no-evidence` | Pass |
| 3 Route 1 | one line, `Only in .../over/.claude/skills: recipe-from-project`; `fresh=0 override=0 diff_lines=1 new_skill_line=1` | Pass |
| push | `git -C ~/github.com/patrickclery/rules push origin main`: `ee57bb4..611a89e`, no force, after gates 1-3 | Done |
| 4 Push order | `pushed-in-order`, `behind_ahead=0 0`; `~/.config/ruly/recipes.yml` unmodified (mtime 2026-10-05) | Pass |

No sync was run. The mirror under `~/.config/ruly/` updates the next time the user runs `ruly squash --sync`. No `lib/` file changed (`git diff --name-only` on `lib/` over the plan range is empty, and PR #5 has only two paths).

## Human checks (run headless)

Setup: the 08-01 "Session setup for human checks" block, using the URL `https://github.com/patrickclery/ruly/blob/main/skills/recipe-from-project.md` in place of the local path. It squashes `ruly-tools` in a temp cwd under a temp HOME, with a `git clone` of the rules repo as the copy. Each check ran `claude -p "/recipe-from-project <TARGET>\n\nUse the rules clone at <copy>." --add-dir <TARGET> --add-dir <copy> --allowedTools "Bash,Read,Glob,Grep" --output-format json` from the temp cwd with the real HOME.

| Check | Observed | Result |
| ----- | -------- | ------ |
| B: this repo (session 5d2a0221) | The URL-fetched skill loaded and got the path. It wrote no recipe because nothing matches. It listed the three commands `add-core-subagent.md`, `ruly/compress.md`, `ruly/decompose.md` and `CLAUDE.md`, and flagged the name `ruly` as taken. The copy status and the real clone status were both empty | Pass |
| D rerun: agile (session 97a0db35), the check left open after 206e44d | All 11 commands listed in full with no shorthand (10 `comms/commands/*`, plus `workaxle/orchestrator/commands/spike.md`), 9 files, `omit_command_prefix` labelled inferred with a reason, 6 skills and 7 rule files pruned, "Nothing has been written yet". Both statuses were empty | Pass on full listing |

## Deviations from Plan

### Recorded differences

- **Session setup for rules-push yes:** the plan says `ruly squash ruly-tools --sync` with the real HOME. Instead I used the URL with the temp HOME setup, because the orchestrator forbade modifying `~/.config/ruly/` and the plan forbids a real HOME sync. Both setups deliver the same URL-fetched skill. Gate 2 proves the skill body is identical.
- **Ahead count:** 21 commits at the checkpoint, against 11 at planning. The extra commits are 08-01 and 08-02 work, and none of them go into the PR beyond the five listed.
- **agile pruning:** this run pruned 7 rule files. 08-01's run pruned 10. The skill applied the same requires-reachability rule, and this session's root set had 9 files. That is model variance in which entries became roots, not a regression of the fix.
- **PR body:** it ends with the Claude Code line followed by the session URL. The session attribution requires that URL, and it comes after the line the plan asked for.
- The local and remote branch `gsd/08-recipe-from-project` was left in place after the merge.

## Deferred follow-ups

None of these are fixed in this phase, and no Ruby changed.

1. In a dry run, a missing local path exits 0 instead of reaching `report_source_failures!`.
2. `--strict` misses `requires:` targets.
3. A dry run does not check unknown `mcp_servers:` names or `subagents[].recipe`.
4. Two existing skills have block-scalar descriptions that the single-line frontmatter parser destroys.
5. The installed `ruly` binary is still 0.1.0, against 0.4.0 in the repo (`ruly version` prints `Ruly v0.1.0`).

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: skills/recipe-from-project.md on main (gh api ?ref=main exit 0)
- FOUND: 0d91b71 is origin/main; 611a89e is rules origin/main
- FOUND: no leftover worktree; checkout branch unchanged
