---
phase: 02-lean-out-native-duplication
verified: 2026-11-02T09:40:00Z
status: passed
score: 11/11 must-haves verified
covered_files:
  - ".planning/phases/02-lean-out-native-duplication/02-01-PLAN.md"
  - ".planning/phases/02-lean-out-native-duplication/02-01-SUMMARY.md"
  - ".planning/phases/02-lean-out-native-duplication/02-02-PLAN.md"
  - ".planning/phases/02-lean-out-native-duplication/02-02-SUMMARY.md"
  - ".planning/phases/02-lean-out-native-duplication/02-03-PLAN.md"
  - ".planning/phases/02-lean-out-native-duplication/02-03-SUMMARY.md"
  - ".planning/phases/02-lean-out-native-duplication/AUDIT.md"
  - "CHANGELOG.md"
  - "README.md"
  - "lib/ruly/cli.rb"
  - "lib/ruly/operations/stats.rb"
  - "lib/ruly/services/display.rb"
  - "lib/ruly/services/mcp_manager.rb"
  - "lib/ruly/services/recipe_loader.rb"
  - "lib/ruly/services/squash_helpers.rb"
  - "lib/ruly/version.rb"
  - "spec/ruly/cli_removed_options_spec.rb"
  - "spec/ruly/cli_stats_spec.rb"
  - "spec/ruly/operations/stats_spec.rb"
  - "spec/ruly/recipe_key_warnings_spec.rb"
covered_digest: "v3:sha256:584b171b743342e64e75dcd03d87f36ccd366e263687439cdfa47018063bf55f"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 2: Lean Out Native Duplication Verification Report

**Phase Goal:** Strip ruly down to its unique strengths by removing or delegating features Claude Code now provides natively. Audit each CLI command and output type, keep recipes + `requires:` + per-subagent model + sync/overrides + post-squash checks, and deprecate the rest.
**Verified:** 2026-11-02
**Status:** passed
**Re-verification:** No, initial verification (includes code-review fixes WR-01..04, IN-01)

ROADMAP lists no Success Criteria for Phase 2, so truths come from the three PLAN `must_haves` plus the goal.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `squash --cache/--no-cache`, `-T`, `--keep-taskmaster`, `clean -T` exit 1 with `Unknown switches` | VERIFIED | Ran each through `bin/ruly` in a temp dir: all print `Unknown switches "<flag>"`. `check_unknown_options!` at cli.rb:21 |
| 2 | `clean --deepclean --dry-run` never lists `.taskmaster/`, even if the directory exists | VERIFIED | Created `.taskmaster/`; dry-run lists only `.claude/`, `CLAUDE.local.md`, `.mcp.json`. No `taskmaster` match in `lib/` |
| 3 | `-a sgpt` / `-a shell_gpt` write plain markdown, no role-JSON writer | VERIFIED | `squash demo -a sgpt -o x.json` wrote markdown plus the stderr notice. No `write_shell_gpt_json` in `lib/` |
| 4 | Kept flags still parse (`--toc`, `--essential`, `--clean`, `--deepclean`, `--dry-run`, `--sync`, `--strict`) | VERIFIED | Options at cli.rb:36-52; `squash demo --toc --essential` ran; `squash --help` lists them |
| 5 | `import`, `analyze`, `mcp` print `Could not find command` (exit 1); `help` lists none | VERIFIED | Ran all three; `ruly help` lists clean, help, init, introspect, list-recipes, squash, stats, version |
| 6 | `ruly stats` is the single token command and prints `Generated <file>` / `N files, X tokens total` | VERIFIED | `stats demo` printed both lines. `Operations::Stats.display_result` in stats.rb; `analyzer.rb` and `contexts.yml` deleted |
| 7 | Recipe `mcp_servers:` still writes `.mcp.json`, including servers propagated from subagent recipes | VERIFIED | With a flat `~/.config/ruly/mcp.json`, squash wrote `.mcp.json` with `teams` and `memory` (memory from the subagent recipe). Subagent frontmatter carries `model: haiku` |
| 8 | Removed or unknown recipe keys warn on stderr (key name only) and squash exits 0 | VERIFIED | `tier` and `bogus` each warned once, plus top-level `tier:` in both config files; squash completed with exit 0; values never printed |
| 9 | No unsafe `YAML.load_file` in `lib/` | VERIFIED | `grep` finds only `safe_load_file` |
| 10 | AUDIT.md gives every command, flag, output type and recipe key a verdict, and justifies shell_gpt drop and cursor keep | VERIFIED | AUDIT.md tables cover commands, flags, outputs, recipe keys. I diffed the lists against the Thor `desc`/`option` declarations in cli.rb and found no gaps. The "Discretion" section justifies shell_gpt vs cursor |
| 11 | `ruly version` prints `Ruly v0.2.0`; CHANGELOG has `[0.2.0]` listing removals; README documents `stats` and the key warning, no longer documents removed features | VERIFIED | `Ruly v0.2.0` printed. CHANGELOG `## [0.2.0] - 2026-11-02`. README has no `analyze`/`import`/`mcp` command/`--cache`/cache/`tier:` docs (only the warning note at line 808). `site/` has zero references |

**Score:** 11/11 truths verified (0 behavior-unverified)

## Prohibitions (must_haves.prohibitions)

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| Do NOT remove `--toc` / `--essential` | HELD | cli.rb:44-45 |
| Do NOT remove skills/commands/subagents generation or hook propagation | HELD | cli.rb:355-371 (`save_command_files`, `save_skill_files`, `propagate_hooks_to_subdirs`); live run produced `.claude/agents/subby.md` and `.claude/settings.local.json` with hooks |
| Do NOT remove cursor or `.mcp.yml` writer | HELD | cursor handled at cli.rb:540-544; `.mcp.yml` at 457-462 |
| Do NOT remove recipe `mcp_servers:` machinery or `copy_scripts` | HELD | cli.rb:360, 367 |
| Do NOT make unknown keys a hard error; do NOT print values | HELD | Run exits 0; spec asserts values are absent |
| Do NOT edit `CLAUDE.local.md`, `rules/`, `site/`, `CLAUDE.md`, `docs/superpowers/`; do NOT stage `Gemfile.lock` | HELD | `git diff 66bde3c HEAD --name-only` lists none of them; `Gemfile.lock` is only a working-tree modification |
| Do NOT rewrite README positioning (Phase 3) | HELD | README diff is limited to removed-feature and stats/warning text |

No judgment- or test-tier prohibitions went unresolved.

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `lib/ruly/cli.rb` | VERIFIED | `check_unknown_options!`; no cache/taskmaster/shell_gpt paths |
| `lib/ruly/operations/stats.rb` | VERIFIED | `display_result` wired from the `stats` command |
| `lib/ruly/services/recipe_loader.rb` | VERIFIED | `KNOWN_RECIPE_KEYS`, `REMOVED_RECIPE_KEYS = %w[tier]`, `config_key_warnings`; wired in `load_sources` and `load_recipes_and_warn` |
| `lib/ruly/services/mcp_manager.rb` | VERIFIED | Only the recipe-driven functions remain |
| `spec/ruly/cli_removed_options_spec.rb`, `recipe_key_warnings_spec.rb`, `cli_stats_spec.rb` | VERIFIED | Exist and pass |
| `AUDIT.md`, `CHANGELOG.md`, `version.rb`, `README.md` | VERIFIED | See truths 10-11 |
| `02-rspec-baseline.txt` | VERIFIED | Present |

## Key Links

| From | To | Status |
|------|----|--------|
| `cli.rb#stats` | `Stats.display_result` | WIRED |
| `cli.rb#load_sources` | `RecipeLoader.recipe_key_warnings` | WIRED (live warning seen) |
| `cli.rb#post_squash` | `MCPManager.update_mcp_settings` | WIRED (live `.mcp.json`) |
| `cli.rb#post_squash` | `propagate_hooks_to_subdirs`, `save_command_files`/`save_skill_files` | WIRED |
| CHANGELOG `[0.2.0]` | `version.rb` | WIRED (both 0.2.0) |

## Behavioral Spot-Checks and Test Gate

| Check | Result | Status |
|-------|--------|--------|
| `bundle exec rspec` | 507 examples, 15 failures, 1 pending. All 15 descriptions are in `02-rspec-baseline.txt` (`comm -23` shows 0 new) | PASS |
| Removed switches and commands (see truths 1, 5) | Exit 1 with the expected messages | PASS |
| Real squash with subagent, hooks, mcp servers, `tier`/`bogus` keys | Exit 0, correct artifacts and warnings | PASS |

The 15 remaining failures are the pre-existing baseline (frontmatter stripping, `get_source_key`, requires ordering, clean/mcp-frontmatter specs). They are unrelated to the removals.

## Requirements Coverage

Roadmap lists no requirement IDs for Phase 2. The plans reference v1 IDs: CLI-01, CLI-02, CLI-03, CLI-04, CLI-06, AGNT-01, AGNT-03, RCPE-01. All exist in REQUIREMENTS.md.

| Requirement | Status | Evidence |
|-------------|--------|----------|
| CLI-01 squash, CLI-02 stats, CLI-03 clean | SATISFIED | Commands work as above |
| CLI-04 import, CLI-06 analyze | SATISFIED (as removed) | REQUIREMENTS.md marks them `Removed (Phase 2)`; commands gone |
| AGNT-01 | SATISFIED (reduced) | Claude and cursor retained; Shell-GPT removal annotated |
| AGNT-03 | SATISFIED | `.mcp.json` generated from recipe `mcp_servers:` |
| RCPE-01 | SATISFIED | Recipes load; unknown keys warn |

No orphaned requirements.

## Anti-Patterns

No `TBD`/`FIXME`/`XXX` markers in the changed lib or new spec files. `rubocop lib` reports 30 offenses; the REVIEW-FIX report says the offense counts did not increase. They are style offenses, not blockers.

## Human Verification Required

None.

## Non-Blocking Notes

1. `TODO.md:69` still mentions `ruly import --toon`, and `docs/claude-code-proxy.md` is a TaskMaster setup guide. Neither relies on a ruly flag; AUDIT.md already lists them as follow-ups.
2. README line 961 documents `introspect [FILE_PATH]`, but the CLI is `introspect RECIPE SOURCE...`. This predates the phase.
3. `.planning/codebase/` maps still describe Analyzer, the cache and Shell-GPT (recorded in AUDIT.md follow-ups).
4. `ruly stats` writes `stats.md` under the gem's `rules/` directory regardless of cwd. This predates the phase. My spot-check created `rules/stats.md` (git-ignored) and I deleted it.

## Gaps Summary

No gaps. Every removal, retention and warning behavior was exercised through the real CLI. The test suite shows no new failures against the baseline. The audit, version bump, changelog and docs match the code.

---

_Verified: 2026-11-02_
_Verifier: Claude (gsd-verifier)_
