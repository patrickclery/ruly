# Compliance benchmark: claude-sonnet-5-5

> These numbers come from the synthetic fixture corpus in `bench/fixtures/corpus`. They are not a measurement of any real rules repository.

One sample per task and condition: these counts are not statistically significant.

## Conditions

- **ruly**: `claude -p` in a workspace holding only the outputs of `ruly squash RECIPE` (CLAUDE.local.md and .claude/).
- **native**: `claude -p` in a workspace holding the native Claude Code layout of the same corpus (.claude/rules/ with `paths:` kept, .claude/skills/, .claude/commands/).

Both conditions run with only the Skill tool enabled (`--tools Skill`) and no MCP servers (`--strict-mcp-config`): the model cannot read, search, edit, run commands, start subagents or browse.

## Results

| Task | Recipe | ruly | native |
|---|---|---|---|
| ruby-single-quotes | ruby-feature | pass | pass |
| frozen-string-literal | ruby-feature | pass | pass |
| no-puts-in-library | ruby-feature | pass | pass |
| rspec-expect | testing | pass | pass |
| commit-subject | pr-review | pass | pass |
| migration-up-down | ruby-feature | pass | fail |
| react-named-export | frontend | pass | fail |
| bug-root-cause | bug | pass | pass |

## Failures

- migration-up-down (native): fail: `forbid code /\bdef change\b/`, `require code /\bdef up\b/`, `require code /\bdef down\b/`
- react-named-export (native): fail: `forbid code /\bexport\s+default\b|\bas\s+default\b/`

## Totals

- ruly: 8/8 passed, 0 errors
- native: 6/8 passed, 0 errors

Total cost: $0.8967 (model `claude-sonnet-5-5`).
