---
phase: 02-lean-out-native-duplication
plan: 03
subsystem: docs
tags: [audit, changelog, release, readme, requirements]
status: complete
requires:
  - "02-01: --cache, TaskMaster and shell_gpt removed; check_unknown_options!"
  - "02-02: import/mcp/analyze removed; stats fold; recipe key warnings"
provides:
  - "AUDIT.md: keep/remove/delegate verdict for every command, flag, output type and recipe key"
  - "ruly 0.2.0 (VERSION + CHANGELOG [0.2.0])"
  - "README.md and .claude/ruly-recipes-mcp-patterns.md matching the 0.2.0 CLI"
affects: [03-emphasize-core-advantages, 04-agents-md-output-target, 05-claude-code-plugin-packaging]
tech-stack:
  added: []
  patterns: []
key-files:
  created:
    - .planning/phases/02-lean-out-native-duplication/AUDIT.md
  modified:
    - CHANGELOG.md
    - lib/ruly/version.rb
    - .planning/REQUIREMENTS.md
    - README.md
    - .claude/ruly-recipes-mcp-patterns.md
key-decisions:
  - "AUDIT verdicts: the mcp command and its flags are `delegate` (claude mcp add / Phase 5 plugin .mcp.json); everything else removed is `remove`"
  - "Config-level tier: recorded as remove (inert, not warned) since D-11 covers recipe keys only"
  - "CHANGELOG [0.2.0] also notes list-recipes no longer prints Tier: (02-02 deviation)"
requirements-completed: [CLI-01, CLI-02, CLI-03]
duration: 2 min
completed: 2026-11-02
commits: 2
plan_head_before: ca20d39e0ea3dd47e1694ac9368f973dd6189c1a
plan_head_after: 45d12c5009ce968b593350daf0cfa2ce31c04498
actuals:
  tokens: 6300
  tasks: 2
  commits: 2
coverage:
  - deliverable: "AUDIT.md covers every command, help-listed flag, output type and recipe key"
    human_judgment: false
    verification:
      - kind: command
        ref: "plan Task 1 coverage script (bin/ruly help per command) -> no MISSING lines; 86 verdict rows"
        status: pass
  - deliverable: "0.2.0 release: version, CHANGELOG, REQUIREMENTS"
    human_judgment: false
    verification:
      - kind: command
        ref: "bin/ruly version == 'Ruly v0.2.0'; CHANGELOG '## [0.2.0] - 2026-11-02' with Removed+Changed; 'Removed (Phase 2)' x2"
        status: pass
  - deliverable: "README and MCP-patterns note match the leaner CLI; site/ clean"
    human_judgment: false
    verification:
      - kind: command
        ref: "Task 2 negative/positive grep gates and site/ regression grep"
        status: pass
      - kind: command
        ref: "bundle exec rspec vs 02-rspec-baseline.txt -> 496 examples, 15 failures, no new failures"
        status: pass
---

# Phase 2 Plan 3: Audit, 0.2.0 Release Notes and Docs Summary

**AUDIT.md records 86 keep/remove/delegate verdicts covering all commands, flags, output types and recipe keys. Ruly is bumped to 0.2.0 with a CHANGELOG entry listing every removal. README and the MCP-patterns note now document `ruly stats` and the recipe-key warning instead of analyze/import/mcp/cache/tier.**

## Performance

- **Duration:** ~2 min
- **Completed:** 2026-11-02T09:06Z
- **Tasks:** 2/2
- **Files:** 6 (1 created, 5 modified)

## Accomplishments

- `AUDIT.md` (D-10) has four tables (Commands, Flags, Output Types, Recipe Keys) with a decision-ID legend, the D-13 shell_gpt vs cursor rationale, a docs scan, and follow-ups.
- `CHANGELOG.md` `[0.2.0] - 2026-11-02` has a `### Removed` section (import, analyze, mcp, `--cache`, TaskMaster flags, Shell-GPT JSON, `tier`/`contexts.yml`) and a `### Changed` section (Unknown switches exit 1, recipe-key warnings, stats as the single token report, no `Tier:` in list-recipes).
- `lib/ruly/version.rb` is now `0.2.0`, and `bin/ruly version` prints `Ruly v0.2.0`.
- `REQUIREMENTS.md`: CLI-04 and CLI-06 are marked removed (Traceability `Removed (Phase 2)`), AGNT-01 notes that Shell-GPT was removed, Out of Scope has 6 rows, and the footer date is updated.
- `README.md`: the Smart Caching item, cache bullets, Caching block and cache examples are gone, along with every `tier:` line. The analyze block is replaced by **Token statistics**, the mcp block by a short paragraph pointing to `mcp_servers:` and `claude mcp add`, and the Analyze bullet by the **Stats** bullet. A sentence on the recipe-key warning is added. Subagents, MCP Server Propagation, hooks, skills and commands docs are untouched (there are 15 `mcp_servers` mentions; the baseline had 14).
- `.claude/ruly-recipes-mcp-patterns.md` now uses `ruly squash workaxle-bug` in place of the removed import call.

## Task Commits

1. **Task 1: AUDIT.md, 0.2.0 release notes and version, requirements**: `1ebba03` (docs)
2. **Task 2: README and MCP-patterns note**: `45d12c5` (docs)

## Verification

- Task 1 coverage script: no `MISSING` lines. The verdict-row count is 86 (at least 50 required).
- Task 2 gates: README has no `cach`, no word `tier` and no `ruly analyze|mcp|import`. The patterns note has no `ruly import`. The positive gates (`ruly stats` at least twice, the Stats bullet, the warning sentence, the MCP Server Propagation and Subagents headings) pass. The `site/` regression grep returns 0 lines, so no site edit was needed.
- `bundle exec rspec`: 496 examples, 15 failures, 1 pending. There are no failures outside `02-rspec-baseline.txt` and no errors outside examples.

## Decisions Made

- `mcp [SERVERS...]`, its `--append`/`--recipe` flags and the `.mcp.json` it wrote are marked `delegate`. Every other removed surface is marked `remove`.
- Config-level `tier:` is listed as `remove` (inert and not warned), and the README follow-up says to delete it by hand.

## Deviations from Plan

None. The plan was executed as written. One small addition: the CHANGELOG `### Changed` section also mentions that `list-recipes` dropped its `Tier:` line, which 02-02 removed as a deviation.

## Issues Encountered

None.

## User-facing Follow-ups (from AUDIT.md)

- The `core-debugger` recipe in patrickclery/rules uses the misspelled `omitCommandPrefix` and now warns.
- The top-level `tier:` in `~/.config/ruly/recipes.yml` is inert.
- The `.planning/codebase/*` maps are stale (they still describe Analyzer, the cache and Shell-GPT).
- `TODO.md` still mentions `ruly import --toon`.

## Next Phase Readiness

Phase 2 is complete. It is ready for phase verification and then Phase 3 (positioning in README).

## Self-Check: PASSED

- FOUND: .planning/phases/02-lean-out-native-duplication/AUDIT.md
- FOUND commits: 1ebba03, 45d12c5
