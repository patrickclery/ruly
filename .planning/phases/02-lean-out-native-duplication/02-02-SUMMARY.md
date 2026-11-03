---
phase: 02-lean-out-native-duplication
plan: 02
subsystem: cli
tags: [cli, thor, stats, mcp, recipes, removal]
status: complete
requires:
  - "02-01: Thor check_unknown_options! and cli_removed_options_spec.rb"
provides:
  - "Command surface: squash, clean, list-recipes, introspect, init, version, stats (+ help)"
  - "Operations::Stats.display_result / Stats.format_number (console summary formerly on Analyzer)"
  - "RecipeLoader::KNOWN_RECIPE_KEYS, REMOVED_RECIPE_KEYS, recipe_key_warnings"
  - "Squash warns on stderr, once per recipe per run, for removed/unknown recipe keys"
affects: [02-03, 04-agents-md-output-target]
tech-stack:
  added: []
  patterns:
    - "Warn-and-continue for recipe schema drift: pure warning builder in RecipeLoader, stderr emission in CLI#load_sources guarded by a per-run Set"
key-files:
  created:
    - spec/ruly/recipe_key_warnings_spec.rb
  modified:
    - lib/ruly/cli.rb
    - lib/ruly/services/display.rb
    - lib/ruly/services/mcp_manager.rb
    - lib/ruly/services/recipe_loader.rb
    - lib/ruly/operations.rb
    - lib/ruly/operations/stats.rb
    - spec/ruly/cli_mcp_spec.rb
    - spec/ruly/cli_removed_options_spec.rb
    - spec/ruly/operations/stats_spec.rb
  deleted:
    - lib/ruly/operations/analyzer.rb
    - lib/ruly/contexts.yml
key-decisions:
  - "D-03 fold interpretation: stats keeps its file/recipe token report and gains Analyzer's console summary; context-window percentages (--tier, tier:, contexts.yml) are dropped"
  - "list-recipes no longer prints the removed `tier:` key (dead display of a removed key)"
  - "Recipe key warnings are checked once per recipe name per CLI run; values are never printed (T-02-05)"
requirements-completed: [CLI-02, CLI-04, CLI-06, AGNT-03, RCPE-01]
duration: 6 min
completed: 2026-11-02
commits: 5
plan_head_before: e6698e0716600798f5a31eb2a6f440b4956b05db
plan_head_after: c8411a9088c3de3c4e24086108b88990a7d5e3b5
actuals:
  tokens: 10200
  tasks: 3
  commits: 5
coverage:
  - deliverable: "import and mcp commands removed; recipe mcp_servers: still writes .mcp.json"
    human_judgment: false
    verification:
      - kind: test
        ref: "spec/ruly/cli_removed_options_spec.rb#with removed commands"
        status: pass
      - kind: test
        ref: "spec/ruly/cli_mcp_spec.rb#squash MCP propagation, #collect_all_mcp_servers"
        status: pass
  - deliverable: "analyze folded into stats; Analyzer, contexts.yml and YAML.load_file gone"
    human_judgment: false
    verification:
      - kind: test
        ref: "spec/ruly/operations/stats_spec.rb#.display_result, #.format_number"
        status: pass
      - kind: command
        ref: "bin/ruly stats demo (temp HOME) prints 'tokens total'; bin/ruly help lists stats and none of analyze/import/mcp"
        status: pass
  - deliverable: "Removed/unknown recipe keys warn on stderr and squash continues"
    human_judgment: false
    verification:
      - kind: test
        ref: "spec/ruly/recipe_key_warnings_spec.rb"
        status: pass
      - kind: command
        ref: "bin/ruly squash demo --dry-run with tier: + omitCommandPrefix: -> exit 0, both warnings, no values echoed"
        status: pass
---

# Phase 02 Plan 02: Remove import/mcp/analyze, recipe key warnings Summary

**`ruly import`, `ruly mcp` and `ruly analyze` are gone (Thor exits 1 with `Could not find command`). `stats` is the single token-reporting command and owns the console summary. Squash now warns on stderr about removed (`tier`, `cache`) or unknown recipe keys and carries on.**

## Performance

- **Duration:** ~6 min
- **Completed:** 2026-11-02T09:03Z
- **Tasks:** 3/3
- **Files:** 13 (1 created, 9 modified, 2 deleted, 1 file's describe restructured), +173 / -793 lines

## Accomplishments

- `import` and `mcp` commands deleted, along with `Display.import_dry_run` and the four helpers only `mcp` used (`load_mcp_server_definitions`, `collect_recipe_mcp_servers`, `build_selected_servers`, `write_mcp_json`). Recipe `mcp_servers:`, `merge_mcp_servers`, `update_mcp_settings`, `collect_all_mcp_servers`, `load_mcp_servers_from_config` and `ScriptManager.copy_scripts` are unchanged (D-02, D-04).
- `Stats.display_result` and `Stats.format_number` are now class methods, moved verbatim from Analyzer. The private instance `format_number` delegates to the class method. `analyze`, `--tier`, `lib/ruly/operations/analyzer.rb` and `lib/ruly/contexts.yml` are deleted. This also removes the only `YAML.load_file` in lib/ (T-02-04).
- Added `RecipeLoader.recipe_key_warnings` (pure) and `CLI#warn_recipe_keys`. Subagent recipes go through `load_sources`, so they are checked as well, and each recipe name is checked only once per run (D-11).

## Task Commits

1. **Task 1: Remove `import` and `mcp`**: `5212149` (feat; the RED examples were written first and seen failing 2/13, then committed together with the implementation)
2. **Task 2: Fold `analyze` into `stats`**: `2df58a9` (test, RED), `61f4a71` (feat, GREEN)
3. **Task 3: Recipe key warnings**: `07716a8` (test, RED), `c8411a9` (feat, GREEN)

## TDD Gate Compliance

- Task 1 RED: 2 failures (both removed commands still dispatched). GREEN: 22/22 across cli_removed_options_spec and cli_mcp_spec. RED and GREEN share one commit.
- Task 2 RED: 5 failures (methods undefined). GREEN: 55/55.
- Task 3 RED: 6 of 7 failing. The no-values example passed already because nothing was printed yet. GREEN: 7/7.

## Verification

- Full `bundle exec rspec`: 496 examples, 15 failures, 1 pending. No failure falls outside `02-rspec-baseline.txt`, and no errors occurred outside examples.
- RuboCop on the 10 touched files: 10 offenses, within the gate of 11. These are 4 in stats.rb, 5 in stats_spec.rb and 1 in cli.rb (`Obsession/MethodOrder`), all pre-existing.
- `git grep` for `def import`, `import_dry_run`, `def mcp(`, the four removed MCP helpers, `Analyzer`, `def analyze`, `contexts.yml` and `YAML.load_file` in lib and spec returns nothing.
- `grep -c 'MCPManager.update_mcp_settings(' lib/ruly/cli.rb` returns 2.
- E2E: in a temp project, `bin/ruly stats demo` prints `1 files, 6 tokens total`, and `bin/ruly help` lists only clean/help/init/introspect/list-recipes/squash/stats/version.
- E2E: squashing a recipe containing `tier: claude_max` and `omitCommandPrefix: x` exits 0, prints both warnings and does not print `claude_max`.

## Decisions Made

- D-03 interpretation, recorded for AUDIT.md (Plan 03): `stats` already writes per-file and per-recipe token counts. The fold therefore moved only Analyzer's console summary into it. The context-window percentages (model tiers from Dec 2024) were dropped and not ported.
- The CLI warning check uses a `Set` held on the CLI instance, so a recipe shared by two subagents warns only once.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `list-recipes` still displayed the removed `tier:` key**
- **Found during:** Task 2
- **Issue:** `Display.recipe_listing` printed `🎯 Tier: ...` for a key that no code reads any more, which misrepresents what the recipe does.
- **Fix:** Removed that line. No spec asserted it.
- **Files modified:** lib/ruly/services/display.rb
- **Commit:** 61f4a71

**2. [Rule 1 - Lint] RSpec/MultipleDescribes in the new spec**
- **Found during:** Task 3
- **Issue:** The plan's two top-level describes (`RecipeLoader` plus `CLI`) added a new offense, which threatened the 11-offense gate.
- **Fix:** Moved both under a single `RSpec.describe Ruly::Services::RecipeLoader`. The CLI group builds `Ruly::CLI.new` explicitly.
- **Files modified:** spec/ruly/recipe_key_warnings_spec.rb
- **Commit:** c8411a9

**Kept as-is:** after the deletions, the `Metrics/ModuleLength` disable on `MCPManager` is still needed (the module is 106 of 100 lines), so it stays.

**Total deviations:** 2 auto-fixed. **Impact:** the only user-visible change is that `list-recipes` no longer prints a `Tier:` line.

### Intentional Deletions

- `lib/ruly/operations/analyzer.rb` and `lib/ruly/contexts.yml`, removed with `git rm` per Task 2.

## Issues Encountered / Notes for the user

- **`omitCommandPrefix` typo in synced rules:** `ruly squash core-debugger --dry-run` now prints `⚠️  Recipe 'core-debugger': unknown key 'omitCommandPrefix' is ignored`. The recipe in patrickclery/rules should use `omit_command_prefix`. Per the plan this is reported here and not fixed, since rules/ is out of scope.
- **Top-level `tier:` in `~/.config/ruly/recipes.yml`:** this key is now inert and produces no warning, because D-11 covers recipe keys, not top-level config keys. It can be deleted by hand.
- README still documents `analyze`, `import`, `mcp` and `tier:`. Plan 03 (D-12) owns the README update.

## Next Phase Readiness

Ready for 02-03: README, CHANGELOG, AUDIT.md and the version bump.

## Self-Check: PASSED

- FOUND: spec/ruly/recipe_key_warnings_spec.rb
- ABSENT (as intended): lib/ruly/operations/analyzer.rb, lib/ruly/contexts.yml
- FOUND commits: 5212149, 2df58a9, 61f4a71, 07716a8, c8411a9
