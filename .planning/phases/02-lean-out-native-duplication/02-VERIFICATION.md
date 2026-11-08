---
phase: 02-lean-out-native-duplication
verified: 2026-11-08T12:00:00Z
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
covered_digest: "v3:sha256:644921d5a6b7c6224f40b46b8cc7070c002d2382e114a59d03ba0d0f7b4857fb"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 11/11
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 2: Lean Out Native Duplication Verification Report

**Phase Goal:** Strip ruly down to its unique strengths by removing or delegating features Claude Code now provides natively. Audit each CLI command and output type, keep recipes + `requires:` + per-subagent model + sync/overrides + post-squash checks, and deprecate the rest.
**Verified:** 2026-11-08
**Status:** passed
**Re-verification:** Yes. The earlier report went stale because README.md changed (phase 08 added the `/recipe-from-project` bullet and the "Drafting a Recipe From a Project" section, PRs #5 and #6). Every truth was re-checked against the current tree, which also carries phases 3 to 8.

ROADMAP lists no Success Criteria for Phase 2, so truths come from the three PLAN `must_haves` plus the goal.

## README Change Impact

The new README text is phase 08 content. It does not document any removed feature: a grep of README.md for `analyze`, `ruly import`, `ruly mcp`, `--cache`, `taskmaster`, `shell_gpt`/`sgpt` finds nothing, and `tier:` appears only in the removed-key warning note (lines 603-604). `ruly stats` is documented (lines 470-474). The earlier non-blocking note about the `introspect` signature is resolved: README line 866 now reads `introspect RECIPE SOURCE...`, matching the CLI. No earlier human-verified item exists (none were required), so none changed.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `squash --cache/--no-cache`, `-T`, `--keep-taskmaster`, `clean -T` exit 1 with `Unknown switches` | VERIFIED | Re-ran each through `bin/ruly` in a temp dir: all print `Unknown switches "<flag>"`, exit 1 |
| 2 | `clean --deepclean --dry-run` never lists `.taskmaster/`, even if the directory exists | VERIFIED | Created `.taskmaster/`; dry-run output has 0 `taskmaster` matches. No `taskmaster` match in `lib/` |
| 3 | `-a sgpt` / `-a shell_gpt` write plain markdown, no role-JSON writer | VERIFIED | `squash demo -a sgpt -o x.json` wrote markdown (`---` frontmatter) and stderr `shell_gpt JSON output was removed in ruly 0.2.0; writing markdown instead`. No `write_shell_gpt_json` in `lib/` |
| 4 | Kept flags still parse (`--toc`, `--essential`, `--clean`, `--deepclean`, `--dry-run`, `--sync`, `--strict`) | VERIFIED | `squash demo --toc --essential` ran, exit 0; `clean --deepclean --dry-run` ran |
| 5 | `import`, `analyze`, `mcp` print `Could not find command` (exit 1); `help` lists none | VERIFIED | Ran all three; `ruly help` lists clean, help, init, introspect, list-recipes, squash, stats, version |
| 6 | `ruly stats` is the single token command and prints `Generated <file>` / `N files, X tokens total` | VERIFIED | `stats demo` printed `Generated .../rules/stats.md` and `1 files, 11 tokens total`. `lib/ruly/operations/` holds only `base.rb` and `stats.rb` (no `analyzer.rb`) |
| 7 | Recipe `mcp_servers:` still writes `.mcp.json` | VERIFIED | With `~/.config/ruly/mcp.json` defining `teams`, squash wrote `.mcp.json` with `teams`; `-a sgpt` run wrote `.mcp.yml`. Subagent propagation covered by the passing specs and the earlier live run |
| 8 | Removed or unknown recipe keys warn on stderr (key name only) and squash exits 0 | VERIFIED | `tier` warned `'tier' was removed in ruly 0.2.0 and is ignored`; `bogus` warned `unknown key 'bogus' is ignored`; exit 0; values not printed |
| 9 | No unsafe `YAML.load_file` in `lib/` | VERIFIED | `grep` finds only `safe_load_file` |
| 10 | AUDIT.md gives every command, flag, output type and recipe key a verdict, and justifies shell_gpt drop and cursor keep | VERIFIED | AUDIT.md still present and unchanged by the README edits; `ruly help` command list matches its command table |
| 11 | CHANGELOG has `[0.2.0]` listing removals; README documents `stats` and the key warning, no longer documents removed features | VERIFIED | CHANGELOG `## [0.2.0] - 2026-11-02` lists every removal. `ruly version` now prints `Ruly v0.4.0` because phases 5 and 6 bumped it (0.3.0, 0.4.0 entries sit above 0.2.0); the 0.2.0 release record and removals are intact. README check above |

**Score:** 11/11 truths verified (0 behavior-unverified)

## Prohibitions (must_haves.prohibitions)

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| Do NOT remove `--toc` / `--essential` | HELD | Both flags run |
| Do NOT remove skills/commands/subagents generation or hook propagation | HELD | Specs for these pass; no new failures (see test gate) |
| Do NOT remove cursor or `.mcp.yml` writer | HELD | `.mcp.yml` written in the live run |
| Do NOT remove recipe `mcp_servers:` machinery or `copy_scripts` | HELD | `.mcp.json` written from recipe |
| Do NOT make unknown keys a hard error; do NOT print values | HELD | Exit 0; only key names printed |
| Do NOT edit `CLAUDE.local.md`, `rules/`, `site/`, `CLAUDE.md`, `docs/superpowers/`; do NOT stage `Gemfile.lock` | HELD | Phase-2 scope unchanged; `Gemfile.lock` remains a working-tree modification only |
| Do NOT rewrite README positioning (Phase 3) | HELD | Phase 2 diff scope was unchanged; later README work belongs to phases 3 to 8 |

No judgment- or test-tier prohibitions went unresolved.

## Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `lib/ruly/cli.rb` | VERIFIED | Unknown-switch handling; no cache/taskmaster/shell_gpt paths |
| `lib/ruly/operations/stats.rb` | VERIFIED | Wired from the `stats` command |
| `lib/ruly/services/recipe_loader.rb` | VERIFIED | `config_key_warnings` live (warnings seen) |
| `lib/ruly/services/mcp_manager.rb` | VERIFIED | Recipe-driven `.mcp.json` written |
| `spec/ruly/cli_removed_options_spec.rb`, `recipe_key_warnings_spec.rb`, `cli_stats_spec.rb` | VERIFIED | Exist; no failures among them |
| `AUDIT.md`, `CHANGELOG.md`, `version.rb`, `README.md` | VERIFIED | See truths 10-11 |
| `02-rspec-baseline.txt` | VERIFIED | Present |

## Key Links

| From | To | Status |
|------|----|--------|
| `cli.rb#stats` | `Stats.display_result` | WIRED (live output) |
| `cli.rb#load_sources` | `RecipeLoader.recipe_key_warnings` | WIRED (live warnings) |
| `cli.rb#post_squash` | `MCPManager.update_mcp_settings` | WIRED (live `.mcp.json`) |
| CHANGELOG `[0.2.0]` | release record | WIRED (entry present; version advanced by later phases) |

## Behavioral Spot-Checks and Test Gate

| Check | Result | Status |
|-------|--------|--------|
| `bundle exec rspec` (single full run) | 910 examples, 15 failures, 1 pending. Compared against `02-rspec-baseline.txt`: `comm -23` shows 0 failures not in the baseline | PASS |
| Removed switches and commands (truths 1, 5) | Exit 1 with the expected messages | PASS |
| Real squash with `tier`/`bogus` keys, mcp servers, sgpt agent | Exit 0, correct artifacts and warnings | PASS |

The 15 failures are the pre-existing baseline, unrelated to the removals.

## Requirements Coverage

Roadmap lists no requirement IDs for Phase 2. The plans reference CLI-01, CLI-02, CLI-03, CLI-04, CLI-06, AGNT-01, AGNT-03, RCPE-01. All exist in REQUIREMENTS.md.

| Requirement | Status | Evidence |
|-------------|--------|----------|
| CLI-01 squash, CLI-02 stats, CLI-03 clean | SATISFIED | Commands work as above |
| CLI-04 import, CLI-06 analyze | SATISFIED (as removed) | REQUIREMENTS.md marks them removed in Phase 2; commands gone |
| AGNT-01 | SATISFIED (reduced) | Claude and cursor retained; Shell-GPT removal annotated |
| AGNT-03 | SATISFIED | `.mcp.json` generated from recipe `mcp_servers:` |
| RCPE-01 | SATISFIED | Recipes load; unknown keys warn |

No orphaned requirements.

## Anti-Patterns

No `TBD`/`FIXME`/`XXX` markers introduced by Phase 2 files. Style-only rubocop offenses were not worsened (per REVIEW-FIX).

## Human Verification Required

None.

## Non-Blocking Notes

1. `TODO.md:69` still mentions `ruly import --toon`; AUDIT.md already lists it as a follow-up.
2. `ruly stats` writes `stats.md` under the gem's `rules/` directory regardless of cwd (pre-existing, git-ignored). The spot-check created `rules/stats.md`; I deleted it.
3. `ruly version` reports 0.4.0, not the 0.2.0 that Phase 2 shipped; this is expected from later phases.

## Gaps Summary

No gaps. The README change only adds phase 08 content and does not reintroduce or document any removed feature. Every removal, retention and warning behavior was re-exercised through the real CLI, and the test suite shows no failures beyond the Phase 2 baseline.

---

_Verified: 2026-11-08_
_Verifier: Claude (gsd-verifier)_
