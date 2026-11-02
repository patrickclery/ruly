# Phase 5: Claude Code Plugin Packaging - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning
**Note:** User was away (asked for unattended work). All decisions below are the recommended defaults, auto-accepted by Claude; revisit on review.

<domain>
## Phase Boundary

Add a plugin output target: `ruly squash RECIPE -a claude-plugin -o DIR` writes a valid Claude Code plugin directory (`.claude-plugin/plugin.json`, `skills/`, `commands/`, `agents/`, `hooks/hooks.json`, `.mcp.json`) from the recipe, so distribution uses the native format. Resolve — with evidence from current Claude Code docs — whether plugins can carry always-on instructions, and handle the squashed rule body accordingly. Existing `.claude/` direct-write output stays the default.

</domain>

<decisions>
## Implementation Decisions

### Invocation
- Reuse `--agent`: new value `claude-plugin` (consistent with Phase 4's `agents` target; no new command or flag)
- `-o` is the output DIRECTORY for this target; default `./ruly-plugin-<recipe>/`
- Plugin `name` = recipe name (kebab-case); `version` = ruly gem version; `description` = recipe `description:`

### Component Mapping
- Recipe skills → `skills/<name>/SKILL.md`; commands → `commands/`; subagents → `agents/<name>.md` (with per-subagent `model:` preserved in frontmatter)
- Recipe `hooks:` → `hooks/hooks.json`; recipe `mcp_servers:` → `.mcp.json` (resolved from `~/.config/ruly/mcp.json` like today)
- Scripts referenced by hooks/rules → `scripts/` inside the plugin, paths rewritten via `${CLAUDE_PLUGIN_ROOT}`

### Always-on Instructions
- Research phase MUST verify against https://code.claude.com/docs/en/plugins-reference whether a plugin can inject always-loaded instructions
- If YES: emit the squashed body through that mechanism
- If NO: emit the squashed body as a skill named `<recipe>-rules` AND print a notice that always-on rules still require `ruly squash` to CLAUDE.local.md; record the finding in README

### Validation
- Spec asserts the generated layout + `plugin.json` schema fields; if `claude plugin validate` (or equivalent) exists locally, plan runs it as an optional verify step

### Claude's Discretion
- Marketplace manifest generation (`marketplace.json`) — include only if trivial

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/ruly/cli.rb` `save_skill_files`, command file writing, `post_squash`
- `lib/ruly/services/subagent_processor.rb` — subagent agent-file generation with model
- `lib/ruly/services/settings_manager.rb` — hooks → settings JSON
- `lib/ruly/services/mcp_manager.rb` — MCP server resolution
- `lib/ruly/services/script_manager.rb` — script collection + path mapping

### Established Patterns
- Services are `module_function`; specs per behavior; README updated for CLI changes

### Integration Points
- New output branch alongside `claude` and `agents` targets in squash

</code_context>

<specifics>
## Specific Ideas

- Research flagged plugin always-on capability as UNCERTAIN (two claims refuted 1–2) — this phase must settle it with primary docs

</specifics>

<deferred>
## Deferred Ideas

- Publishing to a plugin marketplace / registry
- Making plugin output the default target

</deferred>
