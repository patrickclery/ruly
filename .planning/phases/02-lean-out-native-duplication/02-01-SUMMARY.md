---
phase: 02-lean-out-native-duplication
plan: 01
subsystem: cli
tags: [cli, thor, squash, clean, removal]
status: complete
requires: []
provides:
  - "Thor check_unknown_options! on Ruly::CLI: removed switches exit 1 with `Unknown switches`"
  - "squash/clean without --cache, TaskMaster or shell_gpt code paths"
  - "spec/ruly/cli_removed_options_spec.rb regression suite"
affects: [02-02, 02-03, 04-agents-md-output-target]
tech-stack:
  added: []
  patterns:
    - "Hard CLI removal via Thor check_unknown_options! (no deprecation shim)"
key-files:
  created:
    - spec/ruly/cli_removed_options_spec.rb
  modified:
    - lib/ruly/cli.rb
    - lib/ruly/services/display.rb
    - lib/ruly/services/squash_helpers.rb
    - spec/ruly/cli_front_matter_spec.rb
    - spec/ruly/cli_requires_spec.rb
    - spec/ruly/cli_essential_spec.rb
  deleted:
    - spec/ruly/cli_shell_gpt_spec.rb
key-decisions:
  - "Thor check_unknown_options! applies class-wide: any undeclared switch on any command (e.g. `clean --sync`) now exits 1 instead of being ignored"
  - "D-13 discretion: shell_gpt/sgpt dropped; those agent names now fall through to plain markdown output; cursor kept"
requirements-completed: [CLI-01, CLI-03, AGNT-01]
duration: 3 min
completed: 2026-11-02
commits: 5
plan_head_before: 66bde3c80ea1f9cf43c69216a3dd6aede1ecdb6e
plan_head_after: a2664eb4df2e5ad442ccb093c5f3295bcb5092d1
actuals:
  tokens: 7700
  tasks: 3
  commits: 5
coverage:
  - deliverable: "--cache removed; removed switches fail loudly"
    human_judgment: false
    verification:
      - kind: test
        ref: "spec/ruly/cli_removed_options_spec.rb#with the removed --cache switch"
        status: pass
      - kind: command
        ref: "bin/ruly squash --cache --dry-run (temp HOME) -> exit 1, Unknown switches \"--cache\""
        status: pass
  - deliverable: "TaskMaster flags and code removed; clean never targets .taskmaster/"
    human_judgment: false
    verification:
      - kind: test
        ref: "spec/ruly/cli_removed_options_spec.rb#with the removed TaskMaster switches"
        status: pass
      - kind: test
        ref: "spec/ruly/cli_removed_options_spec.rb#when a .taskmaster/ directory exists"
        status: pass
      - kind: command
        ref: "bin/ruly squash -T --dry-run (temp HOME) -> exit 1, Unknown switches \"-T\""
        status: pass
  - deliverable: "shell_gpt role-JSON output removed; sgpt/shell_gpt write markdown"
    human_judgment: false
    verification:
      - kind: test
        ref: "spec/ruly/cli_removed_options_spec.rb#with the removed shell_gpt agent"
        status: pass
      - kind: command
        ref: "full bundle exec rspec vs 02-rspec-baseline.txt -> no new failures"
        status: pass
---

# Phase 02 Plan 01: Remove --cache, TaskMaster and shell_gpt Summary

**`--cache`, `-T/--taskmaster-config`, `--keep-taskmaster` and the shell_gpt role-JSON writer are removed. Thor's `check_unknown_options!` now makes any removed switch exit 1 with `Unknown switches`.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-11-02T08:56:07Z
- **Completed:** 2026-11-02T08:59Z
- **Tasks:** 3/3
- **Files modified:** 8 (1 created, 6 modified, 1 deleted), +127 / -390 lines

## Accomplishments

- Tracer: `--cache` is removed from the option, the code and the display text, and `squash --cache` / `--no-cache` now exit 1 instead of being read as a recipe name.
- TaskMaster flags removed from `squash` and `clean`, along with the import append, the config copy and the dry-run lines. `clean --deepclean` never lists `.taskmaster/` (T-02-01).
- `sgpt` / `shell_gpt` now produce plain markdown. The `write_squash_output` wrapper is gone and `squash` calls `write_markdown_output` directly.
- Unchanged, as required: `--toc`, `--essential`, `--clean`, `--deepclean`, `--sync` and `--strict`, skills/commands/subagents generation, hooks propagation, and cursor `.mcp.yml` output (D-05, D-06, D-08, D-13).

## Task Commits

1. **Task 1: Tracer - remove `--cache`, reject unknown switches** - `5405bf4` (feat)
2. **Task 2: Remove TaskMaster flags** - `5d056e6` (test, RED), `a6f5b60` (feat, GREEN)
3. **Task 3: Drop shell_gpt role-JSON output** - `cfba9ea` (test, RED), `a2664eb` (feat, GREEN)

## TDD Gate Compliance

- Task 2 RED: 4 of the 8 examples failed (the four removed-switch examples). The `.taskmaster` clean example passed already because it guards against regression, not new behavior. GREEN: 8/8 pass.
- Task 3 RED: 2 failures (output was a JSON object instead of markdown). GREEN: 11/11 pass.

## Verification

- `bundle exec rspec`: 496 examples, 15 failures, 1 pending. Every failure is listed in `02-rspec-baseline.txt` (the baseline had 24; 10 of those were in the deleted shell_gpt spec, and 1 baseline failure now passes).
- RuboCop on the 7 touched files: 1 offense, down from the baseline of 2. The remaining one is the pre-existing `Obsession/MethodOrder` on `invoke_clean_if_requested`.
- `git grep -i -e taskmaster -e shell_gpt -e sgpt -- lib spec` (excluding the regression spec) returns nothing.
- `propagate_hooks_to_subdirs` count: 1. `save_command_files|save_skill_files` count: 6.
- End-to-end check: `squash --clean -o out.md -t -e` and `squash --deepclean ...` both exit 0 and write output. This confirms the internal `invoke :clean` still works under the unknown-option check.

## Decisions Made

- `check_unknown_options!` is declared once at class level, so it covers every command. One effect: undeclared switches on other commands (for example `clean --sync`) now exit 1 where they used to be silently ignored. This is intended under D-09.
- D-13 (Claude's discretion): drop shell_gpt and keep cursor. `normalize_agent` no longer maps `sgpt`, so both names are treated as plain non-Claude agents that get markdown output.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Lint] Unused params after branch removal**
- **Found during:** Tasks 1 and 3
- **Issue:** Removing the cache line left `recipe_name` unused in `Display.squash_dry_run`. Removing the shell_gpt branch left `agent` unused in `build_mode_description`. Both raised `Lint/UnusedMethodArgument`.
- **Fix:** Renamed the first to `_recipe_name` (keeps the positional signature for callers). Removed `agent` from `build_mode_description`, whose only caller is `squash_summary`.
- **Files modified:** lib/ruly/services/display.rb
- **Commits:** 5405bf4, a2664eb

**2. [Rule 1 - Lint] Redundant `Metrics/ModuleLength` disable**
- **Found during:** Task 3
- **Issue:** After the deletions, `SquashHelpers` is under the length limit, so the disable directive was flagged as redundant.
- **Fix:** Removed the directive.
- **Files modified:** lib/ruly/services/squash_helpers.rb
- **Commit:** a2664eb

**3. [Rule 1 - Lint] RSpec/DescribeMethod**
- **Found during:** Task 1
- **Issue:** The plan's `RSpec.describe Ruly::CLI, 'removed options'` violated RSpec/DescribeMethod.
- **Fix:** Changed it to `RSpec.describe Ruly::CLI, '.start'`, the entry point the examples drive.
- **Files modified:** spec/ruly/cli_removed_options_spec.rb
- **Commit:** 5405bf4

**Total deviations:** 3 auto-fixed (all lint, needed for the no-new-offenses gate). **Impact:** none on behavior.

### Intentional Deletions

- `spec/ruly/cli_shell_gpt_spec.rb`, removed with `git rm` per Task 3. Every example in it tested the removed format.

## Issues Encountered

None.

## Next Phase Readiness

Ready for 02-02. README, CHANGELOG, AUDIT.md and the version bump are covered by Plan 03.

## Self-Check: PASSED

- FOUND: spec/ruly/cli_removed_options_spec.rb
- ABSENT (as intended): spec/ruly/cli_shell_gpt_spec.rb
- FOUND commits: 5405bf4, 5d056e6, a6f5b60, cfba9ea, a2664eb
