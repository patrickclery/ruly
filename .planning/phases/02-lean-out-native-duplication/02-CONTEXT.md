# Phase 2: Lean Out Native Duplication - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Strip ruly down to its unique strengths by removing CLI commands, flags and outputs that are unrelated to rule composition or duplicate native Claude Code features. Keep recipes, `requires:` resolution, per-subagent model, sync/overrides, post-squash checks, and the `.claude/` component delivery (skills, commands, subagents, hooks). Produce an audit documenting every keep/remove/delegate verdict.

</domain>

<decisions>
## Implementation Decisions

### What Gets Removed
- Remove taskmaster flags (`-T`/`--taskmaster_config`, `--keep_taskmaster`) from `squash` and `clean`, plus their supporting code
- Remove the `ruly import` command — `squash` already handles scripts
- Fold `ruly analyze` into `ruly stats` — one token-reporting command; remove `analyze`
- Remove the standalone `ruly mcp` command; KEEP the recipe `mcp_servers:` key (per-recipe MCP selection is composition)

### Overlapping Features
- KEEP skills/commands/subagents generation into `.claude/` — plugin packaging layers on top in Phase 5
- KEEP recipe `hooks:` and propagation to subagent cwd directories — per-recipe hook selection is composition
- Remove `--cache` flag and its cache read/write code (manual invalidation, squash is fast)
- KEEP `--toc` and `--essential`

### Deprecation Mechanism
- Hard removal (no warning period); minor version bump + CHANGELOG entry
- Deliverable: `AUDIT.md` in this phase directory — every CLI command, flag and output type with keep/remove/delegate verdict and reason
- Removed or unknown recipe keys: squash warns and continues (no hard error)
- Update README.md (required by project rules) and any `site/` docs pages referencing removed features

### Claude's Discretion
- Non-Claude agent outputs (cursor, shell_gpt): Claude decides. Default lean: drop shell_gpt (`sgpt` alias, JSON output), keep cursor until AGENTS.md output lands in Phase 4 — but justify the call in AUDIT.md.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/ruly/cli.rb` — Thor commands: squash, import, clean, list-recipes, introspect, analyze, init, version, mcp, stats
- `lib/ruly/operations/analyzer.rb` and `operations/stats.rb` — overlapping token reporting; merge target is stats
- `lib/ruly/services/mcp_manager.rb` — used by both the `mcp` command and recipe `mcp_servers:`; keep the recipe path
- `lib/ruly/services/script_manager.rb` — `copy_scripts` used by `import`; squash script handling must remain

### Established Patterns
- Services are `module_function` modules; operations subclass `operations/base.rb`
- RSpec suite with WebMock; each removed command has specs that must be removed/updated
- RuboCop enforced (120 col); run `bundle exec rspec` and `bundle exec rubocop` as gates

### Integration Points
- `cli.rb` `normalize_agent` (sgpt → shell_gpt), `write_squash_output` shell_gpt branch, `collect_files_to_clean`
- `cached?` / cache dir `~/.cache/ruly/` in squash flow
- README.md CLI section and `site/` docs

</code_context>

<specifics>
## Specific Ideas

- Source: `.planning/research-competitive-2026-11-01.md` — "Where ruly duplicates native features" and "Where ruly is ahead" sections define keep vs remove
- User preference: minimal design surface — one mechanism per need, no unrequested flags

</specifics>

<deferred>
## Deferred Ideas

- Delegating `.claude/` component output to a plugin layout — Phase 5
- Replacing cursor output with AGENTS.md — Phase 4

</deferred>
