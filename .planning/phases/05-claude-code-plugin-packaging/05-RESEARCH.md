# Phase 5: Claude Code Plugin Packaging - Research

**Researched:** 2026-11-02 (all doc quotes accessed 2026-11-02)
**Domain:** Claude Code plugin format (manifest, components, hooks, MCP) + ruly squash output dispatch
**Confidence:** HIGH (primary docs quoted; layout validated with the local `claude plugin validate`, Claude Code 2.1.304)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Invocation
- Reuse `--agent`: new value `claude-plugin` (consistent with Phase 4's `agents` target; no new command or flag)
- `-o` is the output DIRECTORY for this target; default `./ruly-plugin-<recipe>/`
- Plugin `name` = recipe name (kebab-case); `version` = ruly gem version; `description` = recipe `description:`

#### Component Mapping
- Recipe skills → `skills/<name>/SKILL.md`; commands → `commands/`; subagents → `agents/<name>.md` (with per-subagent `model:` preserved in frontmatter)
- Recipe `hooks:` → `hooks/hooks.json`; recipe `mcp_servers:` → `.mcp.json` (resolved from `~/.config/ruly/mcp.json` like today)
- Scripts referenced by hooks/rules → `scripts/` inside the plugin, paths rewritten via `${CLAUDE_PLUGIN_ROOT}`

#### Always-on Instructions
- Research phase MUST verify against https://code.claude.com/docs/en/plugins-reference whether a plugin can inject always-loaded instructions
- If YES: emit the squashed body through that mechanism
- If NO: emit the squashed body as a skill named `<recipe>-rules` AND print a notice that always-on rules still require `ruly squash` to CLAUDE.local.md; record the finding in README

#### Validation
- Spec asserts the generated layout + `plugin.json` schema fields; if `claude plugin validate` (or equivalent) exists locally, plan runs it as an optional verify step

### Claude's Discretion
- Marketplace manifest generation (`marketplace.json`) — include only if trivial

### Deferred Ideas (OUT OF SCOPE)
- Publishing to a plugin marketplace / registry
- Making plugin output the default target
</user_constraints>

## Summary

**The always-on question is settled: NO, in the sense the CONTEXT decision means.** A Claude Code plugin cannot ship CLAUDE.md-equivalent instructions. The plugin manifest reference says so directly: "A `CLAUDE.md` at the plugin root isn't loaded as context, and `claude plugin validate` warns when it finds one. To include instructions that load into Claude's context, put them in a skill." [CITED: https://code.claude.com/docs/en/plugins-reference]. The local validator printed the same warning when a probe plugin held a CLAUDE.md [VERIFIED: `claude plugin validate`, v2.1.304, output pasted under Always-on Verdict]. Three nearby mechanisms do put plugin text in front of Claude every session, and each fails as a CLAUDE.md replacement. A SessionStart hook's `additionalContext` is capped at 10,000 characters. An output style with `force-for-plugin` replaces the user's own output style and never reaches subagents. A `settings.json` `agent` replaces the whole default system prompt. So the plan takes the locked **NO branch**: write the squashed body as skill `<recipe>-rules`, print the notice, and record the finding in the README.

Everything else maps one to one onto documented plugin locations: `.claude-plugin/plugin.json` (only `name` is required), `skills/<name>/SKILL.md`, `commands/*.md`, `agents/*.md`, `hooks/hooks.json` (same shape as settings `hooks`, inside a top-level `"hooks"` key), `.mcp.json` at the plugin root, and `scripts/` referenced as `"${CLAUDE_PLUGIN_ROOT}/scripts/..."`. One rule changes the subagent output. Plugin agents **ignore** `permissionMode`, `hooks` and `mcpServers` in frontmatter, and ruly writes all three today. Their content has to move to plugin-level `hooks/hooks.json` and `.mcp.json`. `claude plugin validate <dir>` is installed locally (2.1.304) and accepts a ruly-shaped plugin. With `author` and `metadata` added, it also passes `--strict`.

Most of the implementation work is in ruly, not in the plugin format. Every current writer hard-codes a cwd-relative `.claude/...` path: `save_skill_files`, `save_command_files`, `SubagentProcessor` (`.claude/agents`), `copy_script_files` (called *inside* `SourceProcessor.process_for_squash`), `MCPManager.write_claude_mcp_settings` (`.mcp.json`) and `SettingsManager` (`.claude/settings.local.json`). The plugin target needs those writers to take a directory parameter, defaulting to today's path, so the claude/cursor output stays byte-identical. Follow Phase 4's dispatch shape: a `Services::ClaudePlugin` module (module_function), one `if agent == ...` branch in `squash` next to the `AgentsMd` branch, no new branch in `post_squash`, and a marker-gated overwrite guard and clean.

**Primary recommendation:** Add `Services::ClaudePlugin` with `AGENT = 'claude-plugin'`. Add an optional directory keyword to each existing writer. Emit the squashed body as `skills/<recipe>-rules/SKILL.md` plus a one-line notice. Mark the generated directory with `plugin.json` `"metadata": {"generator": "ruly", ...}`, and run `claude plugin validate` as an optional e2e gate.

## Always-on Verdict (primary-source evidence)

| Candidate mechanism | Doc text (verbatim) | Verdict |
|---|---|---|
| CLAUDE.md in plugin | "A `CLAUDE.md` at the plugin root isn't loaded as context, and `claude plugin validate` warns when it finds one. To include instructions that load into Claude's context, put them in a skill." [CITED: code.claude.com/docs/en/plugins-reference, "Standard layout"]; "To include instructions in a plugin, write them as a skill. Claude Code doesn't load a `CLAUDE.md` at the plugin root" [CITED: code.claude.com/docs/en/plugins/components.md, "Skills"] | **Not loaded** |
| Skill | "In a regular session, skill descriptions are loaded into context so Claude knows what's available, but full skill content only loads when invoked." / "Unlike CLAUDE.md content, a skill's body loads only when it's used." [CITED: code.claude.com/docs/en/skills.md] | On demand only (description always listed, body loaded when invoked) |
| SessionStart hook `additionalContext` / plain stdout | "Claude Code adds a SessionStart hook's plain-text stdout to Claude's context." ... "If a value exceeds 10,000 characters, Claude Code writes the text to a file in the session directory and passes Claude the file path with a preview of up to the first 2,000 characters instead. Claude can read the file, but Claude Code doesn't ask it to." ... "Unlike that Bash ceiling, this cap has no setting or environment variable to raise it." Also: "For instructions that never change, prefer CLAUDE.md" and "Text framed as out-of-band system commands can trigger Claude's prompt-injection defenses" [CITED: code.claude.com/docs/en/hooks.md, "SessionStart", "Add context for Claude", "JSON output"] | Always-on, but **capped at 10,000 chars** per string; imperative rule text risks injection defenses. Not a CLAUDE.md substitute |
| Output style `force-for-plugin: true` | "Plugin output styles only. Set to `true` to apply this style automatically whenever the plugin is enabled, without requiring users to select it. Overrides the user's `outputStyle` setting. If multiple enabled plugins set this, Claude Code uses the first one loaded." Output styles "apply to the main conversation and to a fork ... Other subagents run their own system prompt, so styles don't change how they respond." [CITED: code.claude.com/docs/en/output-styles.md] | Always-on, but hijacks the user's output style, first plugin wins, and subagents never see it. Docs position it for voice and format, not project rules |
| Plugin `settings.json` `agent` | "Only two keys take effect from a plugin, `agent` and `subagentStatusLine`" [CITED: components.md]; "a custom subagent's system prompt replaces the default Claude Code system prompt entirely, the same way `--system-prompt` does" [CITED: code.claude.com/docs/en/sub-agents.md] | Replaces the default system prompt. **Unsuitable** |
| CLAUDE.md / memory docs | The memory page mentions plugins only for the built-in `cc-plugin-agents-md@builtin`. It gives third-party plugins no route to load CLAUDE.md or `.claude/rules` [VERIFIED: grep of the fetched code.claude.com/docs/en/memory.md, only the AGENTS.md built-in plugin lines matched] | None |

Validator evidence [VERIFIED: local run, `claude plugin validate ./demo`, Claude Code 2.1.304]:

```
Validating plugin: .../probe/demo/CLAUDE.md
⚠ Found 1 warning:
  ❯ root: CLAUDE.md at the plugin root is not loaded as project context. To ship context with your plugin, use a skill (skills/<name>/SKILL.md) instead.
```

**Decision for the planner:** take the locked NO branch. Do not emit a CLAUDE.md, a SessionStart hook or a `force-for-plugin` output style. All three either break the user's setup or fail on large recipes. Record the table above in the README in condensed form.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `-a claude-plugin` parsing and dispatch | CLI (`lib/ruly/cli.rb`) | — | Same seam as Phase 4's `agents` branch in `squash` and `normalize_agent` |
| Plugin layout, manifest, rules skill, hooks/MCP JSON, marker | Service `Services::ClaudePlugin` (new, module_function) | — | Keeps cli.rb under ClassLength 500 (566 lines today, mid-Phase 4) |
| Skill/command/script file writing | `Services::ScriptManager` (add dir keyword) | — | Reuse `save_skill_files`, `save_command_files`, `copy_scripts(…, destination_dir)` |
| Subagent agent files | `Services::SubagentProcessor` (add agents dir + plugin frontmatter mode) | — | Hard-codes `.claude/agents` and writes plugin-ignored keys |
| MCP server resolution | `Services::MCPManager.load_mcp_servers_from_config` (public, reuse) | CLI `merge_mcp_servers` | Server names already merged from rules + subagents by `merge_mcp_servers` |
| Hook JSON | `Services::ClaudePlugin` (wrap recipe `hooks` under a `"hooks"` key) | — | Shape matches `settings.json` `hooks`; do not reuse `SettingsManager` (it writes settings.local.json) |
| Validation of output | External `claude plugin validate` (optional gate) | RSpec layout/schema specs | Validator is authoritative per docs; specs cannot depend on `claude` being installed |

## Standard Stack

No new dependencies. Ruby stdlib only.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `json` (stdlib) | bundled with Ruby 4.0.1 here | `plugin.json`, `hooks/hooks.json`, `.mcp.json` via `JSON.pretty_generate` | Already used by MCPManager/SettingsManager |
| `fileutils` (stdlib) | bundled | mkdir/cp/rm_rf in output dir | Already used throughout |
| `yaml` (stdlib) | bundled | agent/skill frontmatter | Already used by SubagentProcessor |
| Claude Code CLI `claude plugin validate` | 2.1.304 locally | Optional verify gate | Docs: "`claude plugin validate` is the authoritative check for a manifest" [CITED: plugins-reference] |

**Installation:** none.

## Package Legitimacy Audit

No external packages are installed in this phase. The gate does not apply.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Plugin Format Reference (what ruly must emit)

### Layout [CITED: plugins-reference "Standard layout"; VERIFIED: probe passed `claude plugin validate`]

```
ruly-plugin-<recipe>/                # -o DIR (default ./ruly-plugin-<recipe>/)
├── .claude-plugin/
│   └── plugin.json                  # ONLY the manifest goes in .claude-plugin/
├── skills/
│   ├── <recipe>-rules/SKILL.md      # squashed rule body (NO branch)
│   └── <skill-name>/SKILL.md        # recipe skills
├── commands/<relative path>.md      # recipe commands (subdirs become name segments)
├── agents/<subagent>.md             # subagents
├── hooks/hooks.json                 # recipe hooks:, wrapped in {"hooks": ...}
├── scripts/<file>                   # scripts:, bin files, hook scripts (chmod 755)
└── .mcp.json                        # {"mcpServers": {...}}
```

Doc rule: "Save the manifest at `.claude-plugin/plugin.json` under the plugin root. Put every other plugin file at the plugin root, not inside `.claude-plugin/`." [CITED: plugins-reference]

### plugin.json fields [CITED: plugins-reference "Fields"]

- "`name` is the only required key." "The manifest is optional." Name: "non-empty, with no spaces, `@`, `:`, path separators, control characters ... use kebab-case."
- Reserved names: "Starts with `claude-`, `anthropic-`, `anthropics-`, or `cc-plugin-` | Error"; "Is `claude`, `anthropic`, `anthropics`, `claude-code`, or `claude-mods` | Error". [VERIFIED: probe `claude-core` → `✘ Validation failed`; `work_axle` → kebab-case warning, passes]. Of the 51 recipes in the user's synced recipes.yml, none is non-kebab or reserved [VERIFIED: ruby scan of ~/.config/ruly/remotes/patrickclery/rules/recipes.yml].
- `version`: "A version string, not checked against semver. Setting it pins the plugin to that version until you change it". `--plugin-dir` plugins and plugins in local-path marketplaces load in place and are not pinned [CITED: code.claude.com/docs/en/plugins/loading.md "In-place and copied plugins"].
- `description`, `author` (`name` required inside), `metadata` ("Free-form object for your own data. Claude Code doesn't read it. Requires Claude Code v2.1.222 or later").
- Unknown top-level keys: "the field is stripped and the plugin loads. `claude plugin validate` reports each unrecognized top-level field as a warning".
- With default directories, ruly sets no component keys (`commands`, `agents` etc.). Setting `commands` or `agents` **replaces** the default scan.

Validator results on probes [VERIFIED: local runs]:
- `{"name","version","description"}` only → `Validation passed with warnings` (`author: No author information provided`), exit 0.
- Adding `"author":{"name":"Patrick Clery"}` and `"metadata":{"generator":"ruly","recipe":"demo"}` → `--strict` → `✔ Validation passed`.

### Skills [CITED: components.md "Skills", skills.md]

- `skills/<dir>/SKILL.md`; command name `/<plugin>:<dir>`; frontmatter `name` replaces the last segment.
- `description` is recommended (first body line is used if it is missing). The `claude plugin validate` probe warned `No frontmatter block found` for a SKILL.md without frontmatter [VERIFIED: local run]. **The `<recipe>-rules` skill must carry frontmatter.**
- "the combined `description` and `when_to_use` text is truncated at 1,536 characters"; "Keep `SKILL.md` under 500 lines" (advisory; a 3,000-line probe still validated).
- After compaction: "keeping the first 5,000 tokens of each. Re-attached skills share a combined budget of 25,000 tokens."

### Commands [CITED: components.md "Commands"]

"Save a command at `commands/<file>.md` and it becomes `/<plugin>:<file>`. A subdirectory adds a segment, so `commands/db/migrate.md` is `/my-plugin:db:migrate`." Command files take the same frontmatter as skills.

### Agents [CITED: components.md "Frontmatter fields in plugin agents"; sub-agents.md]

- Supported: "`name`, `description`, `model`, `effort`, `maxTurns`, `autoCompactWindow`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `omitClaudeMd`, `isolation`, `color`, and the `cacheTtl` key of `experimental`."
- **Ignored: "`permissionMode`, `hooks`, `mcpServers`, and `initialPrompt`. An agent file can't add hooks or MCP servers on its own, so add those as plugin hooks and MCP servers instead."** `claude plugin validate` does **not** warn about them [VERIFIED: probe agent with all three passed].
- `model`: "`sonnet`, `opus`, `haiku`, `fable`, a full model ID such as `claude-opus-5-5`, or `inherit`".
- Name: "`<plugin>:<name>`, where `<name>` comes from the frontmatter `name` field, or from the file name"; frontmatter `name` "can't contain `:`".
- `skills` is "a comma-separated string ... or a YAML list" for `tools`; `skills` examples use a YAML list.

### Hooks [CITED: components.md "Hooks"; plugins-reference "hooks"]

- `hooks/hooks.json` "under a top-level `"hooks"` key, in the same shape as the `hooks` object in `settings.json`." "A file that contains only the event map, without that wrapper, fails to load."
- Quoting: "wrap the `${CLAUDE_PLUGIN_ROOT}` path in double quotes"; validator warns on an unquoted variable and `--strict` fails [VERIFIED: probe, `Shell command uses ${CLAUDE_PLUGIN_ROOT} without quotes`].
- "A plugin's hooks don't wait for one of the plugin's skills or commands to be used ... they fire on their events from then on."

### MCP [CITED: components.md "MCP servers"]

`.mcp.json` at the plugin root, `{"mcpServers": {...}}`, "the same shape as a project `.mcp.json`". The server appears as `plugin:<plugin>:<server>` and its tools as `mcp__plugin_<plugin>_<server>__<tool>`. The validator checks MCP entries on Claude Code v2.1.281 or later.

### Path variables [CITED: plugins-reference "Environment variables"]

`${CLAUDE_PLUGIN_ROOT}` resolves in hook `command`/`args`, MCP stdio `command`/`args`/`env`, and "Skill, command, and agent content | Anywhere in the Markdown body". "The variables aren't present in the environment of commands Claude runs through the Bash tool ... In skill, command, and agent content, write the `${...}` reference in the Markdown body instead, and Claude Code substitutes the path inline when it loads the content." **So script references in skill, command and agent bodies should be rewritten to `${CLAUDE_PLUGIN_ROOT}/scripts/<file>`, not `.claude/scripts/<file>`.**

### Local testing

- `claude --plugin-dir <path>`: "Load a plugin from a directory or .zip for this session only" [VERIFIED: `claude --help`, 2.1.304]. It loads in place, with id `<name>@inline` [CITED: loading.md].
- `claude plugin validate [--strict] [--json] <path>` [VERIFIED: `claude plugin validate --help`].
- Auto-load alternative: a directory with `.claude-plugin/plugin.json` under `~/.claude/skills/` or the project's `.claude/skills/` loads as `<name>@skills-dir` [CITED: loading.md]. `claude plugin init` scaffolds there.
- `/reload-plugins` picks up edits mid-session [CITED: components.md].

### marketplace.json (discretion: skip)

Minimal form: `.claude-plugin/marketplace.json` with required `name`, `owner` (`owner.name` required) and `plugins` (entries require `name`, `source`; relative sources start with `./`) [CITED: code.claude.com/docs/en/plugins/marketplace-reference.md]. A probe with `{"name":"ruly-demo","owner":{"name":"ruly"},"plugins":[{"name":"demo","source":"./"}]}` beside plugin.json validated with warnings only (missing `description`) [VERIFIED: local run]. **Recommendation: do not generate it.** `owner.name` needs a value that ruly does not know truthfully, and publishing is deferred. `--plugin-dir` covers local use. One README line can show the minimal form.

## Architecture Patterns

### System Architecture Diagram

```mermaid
flowchart TD
  A["ruly squash RECIPE -a claude-plugin [-o DIR]"] --> B[normalize_agent: claudeplugin → claude-plugin]
  B --> C[load_sources + process_squash_sources<br/>NO bin copy into cwd for this agent]
  C --> D{output dir exists?}
  D -- "yes, plugin.json lacks ruly metadata" --> X[Thor::Error, untouched]
  D -- "yes, ruly-generated" --> E[rm_rf DIR contents]
  D -- no --> F[mkdir DIR]
  E --> F
  F --> G[plugin.json: name/version/description/author?/metadata]
  F --> H["skills/RECIPE-rules/SKILL.md ← squashed body<br/>(script refs → ${CLAUDE_PLUGIN_ROOT}/scripts)"]
  F --> I["skills/NAME/SKILL.md ← ScriptManager.save_skill_files(skills_dir:)"]
  F --> J["commands/ ← save_command_files(commands_dir:)"]
  F --> K["agents/ ← SubagentProcessor(agents_dir:, plugin: true)<br/>drop permissionMode/hooks/mcpServers"]
  F --> L["hooks/hooks.json ← {hooks: recipe hooks}<br/>.claude/scripts/X → \"${CLAUDE_PLUGIN_ROOT}/scripts/X\""]
  F --> M[".mcp.json ← merge_mcp_servers + MCPManager.load_mcp_servers_from_config"]
  F --> N["scripts/ ← copy_scripts(script_files, DIR/scripts) + bin files"]
  G & H & I & J & K & L & M & N --> O[Checks.run_all over rules + skills]
  O --> P["notice: always-on rules need ruly squash → CLAUDE.local.md; skipped: model/isolate"]
```

### Recommended structure

```
lib/ruly/services/claude_plugin.rb   # NEW: AGENT, MARKER_KEY, output_dir, generated?, write_manifest,
                                     #      write_rules_skill, write_hooks, write_mcp, rewrite_hook_commands,
                                     #      skipped_parts/notice
lib/ruly/services.rb                 # require 'services/claude_plugin' (alphabetical, after agents_md)
lib/ruly/services/script_manager.rb  # save_skill_files(skills_dir:), save_command_files(commands_dir:)
lib/ruly/services/subagent_processor.rb  # agents_dir:, plugin frontmatter mode
lib/ruly/services/source_processor.rb    # make the bin-file copy skippable (or give it a destination)
lib/ruly/cli.rb                      # normalize_agent, -a/-o desc, squash branch, write_claude_plugin, clean routing
spec/fixtures/claude_plugin/         # or reuse spec/fixtures/agents_md (already has skills, commands, hooks, mcp, subagent)
spec/ruly/claude_plugin_spec.rb, spec/ruly/cli_claude_plugin_spec.rb
```

### Pattern 1: Phase 4 dispatch shape (copy it)
Phase 4 left this in `squash` [VERIFIED: lib/ruly/cli.rb:85-93 at commit 45e8ffc]:
```ruby
if agent == Services::AgentsMd::AGENT
  write_agents_md(output_file, local_sources:, recipe_config:, recipe_name:, script_files:, script_mappings:,
                               skill_files:)
else
  write_markdown_output(...)
  post_squash(...)
  ...
end
```
Add an `elsif agent == Services::ClaudePlugin::AGENT` branch that calls a private `write_claude_plugin(...)`. Resolve the output dir the way Phase 4 resolves its file (`Services::AgentsMd.output_file(requested, agent)` maps the Thor default `'CLAUDE.local.md'` to `AGENTS.md`, lib/ruly/services/agents_md.rb:21-26): map `nil` or `'CLAUDE.local.md'` to `"ruly-plugin-#{recipe_name}"`. `normalize_agent` already computes `letters = agent&.downcase&.gsub(/[^a-z]/, '')` (cli.rb:257); add `return Services::ClaudePlugin::AGENT if letters == 'claudeplugin'`.

### Pattern 2: Directory keyword with today's default (byte-identical guarantee)
```ruby
# Source: pattern derived from ScriptManager.copy_scripts(script_files, destination_dir = nil), script_manager.rb:172
def save_skill_files(skill_files, find_rule_file:, parse_frontmatter:, strip_metadata:, recipe_paths: Set.new,
                     skills_dir: '.claude/skills')
  ...
  skill_dir = File.join(skills_dir, skill_name)
```
Apply the same keyword to `save_command_files` (`commands_dir:`), `SubagentProcessor.process_subagents`/`generate_agent_file` (`agents_dir:`, plus a `plugin:` flag that drops `permissionMode`, `hooks` and `mcpServers`), and the bin-file copy. Then the Phase 4 differential gate (claude/cursor output byte-identical) still applies.

### Pattern 3: Rules skill (NO branch)
```markdown
---
name: <recipe>-rules
description: Always-on rules for the <recipe> ruly recipe. <recipe description>. Load before starting any task in this project.
---
<squashed body, same as CLAUDE.local.md, script refs rewritten to ${CLAUDE_PLUGIN_ROOT}/scripts/...>
```
Keep `description` under 1,536 characters (truncate the recipe description). Write the body with the existing `Services::SquashHelpers.write_sources(io, local_sources, mappings, toc:)` (Phase 4 extraction), passing plugin-specific script mappings.

### Pattern 4: Hook command rewrite
```ruby
# recipe: command: .claude/scripts/worktree-create.sh   (real recipe, ~/.config/ruly/remotes/patrickclery/rules/recipes.yml:128)
# plugin: command: "\"${CLAUDE_PLUGIN_ROOT}/scripts/worktree-create.sh\""
cmd.gsub(%r{(?<![\w/.])\.claude/scripts/(\S+)}) { "\"${CLAUDE_PLUGIN_ROOT}/scripts/#{Regexp.last_match(1)}\"" }
```
Write `JSON.pretty_generate({'hooks' => rewritten_hooks})`. Warn when a rewritten script is not among the copied scripts.

### Anti-Patterns to Avoid
- **CLAUDE.md in the plugin**: not loaded, and the validator warns about it.
- **SessionStart hook that `cat`s the rules**: anything over 10,000 chars becomes a file path plus a 2,000-char preview. Imperative text may also trip injection defenses.
- **`force-for-plugin` output style**: overrides the user's `outputStyle` and is invisible to subagents.
- **Calling `post_squash` / `SettingsManager.write_settings` / `MCPManager.update_mcp_settings` for this target**: they write `.claude/settings.local.json` and `.mcp.json` into the *cwd*.
- **Setting `commands`/`agents` keys in plugin.json**: they replace the default directory scan. Use the default dirs and omit the keys.
- **Writing `permissionMode: bypassPermissions` into plugin agents**: ignored, so the output would claim a behavior that never happens.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Plugin schema validation | A JSON-schema checker in ruly | `claude plugin validate` (optional gate) + RSpec field assertions | Validator is authoritative and version-aware |
| Squashed body writing | New loop | `SquashHelpers.write_sources` (Phase 4) | Same bytes as CLAUDE.local.md |
| Skill content compile (model re-inject) | New compiler | `ScriptManager.save_skill_files` with a `skills_dir:` keyword | Keeps `compile_skill_with_requires` behavior |
| MCP server lookup | New config reader | `MCPManager.load_mcp_servers_from_config(names)` + CLI `merge_mcp_servers` | Already strips `_` keys and adds `type: stdio` |
| Script collection | New scanner | `ScriptManager.collect_scripts_from_sources` + `copy_scripts(files, dest)` | `destination_dir` param already exists |
| Agent file rendering | New writer | `SubagentProcessor` with `agents_dir:`/`plugin:` | Keeps model resolution (`resolve_agent_model`) |

## Common Pitfalls

### Pitfall 1: Writes leak into the cwd's `.claude/`
**What goes wrong:** `-a claude-plugin` still creates `.claude/scripts`, `.claude/skills` or `.claude/agents` in the project.
**Why:** `SourceProcessor.process_for_squash` runs `ScriptManager.copy_script_files(bin_files) unless bin_files.empty? || dry_run`, which hard-codes `scripts_dir = '.claude/scripts'` [VERIFIED: source_processor.rb:116-117, script_manager.rb:142]. `SubagentProcessor.process_subagents` runs `FileUtils.mkdir_p('.claude/agents')` and `agent_file = ".claude/agents/#{agent_name}.md"` [VERIFIED: subagent_processor.rb:38, 181]. The subagent recipe's sources also go through `process_sources_for_squash` and its bin copy.
**How to avoid:** add a skip or destination parameter for the bin copy and an `agents_dir:` keyword. The e2e test asserts that `.claude`, `CLAUDE.local.md`, `.mcp.json` and `.mcp.yml` are absent in the cwd after the squash.

### Pitfall 2: `squash -a claude-plugin --clean` deletes the project's `.claude/`
**Why:** `invoke_clean_if_requested` → `collect_files_to_clean(agent)` always adds `'.claude/'` and the `-o` path, and adds `.mcp.yml` for any agent other than claude [VERIFIED: cli.rb `collect_files_to_clean` at commit 166c8e8].
**How to avoid:** route the plugin agent first in `collect_files_to_clean`. Return `[dir + '/']` only when `ClaudePlugin.generated?(dir)`, the same shape as Phase 4's `agents_md_files_to_clean`.

### Pitfall 3: Overwriting a hand-made directory
`-o DIR` is a directory that ruly wipes before it regenerates. Gate the wipe on `.claude-plugin/plugin.json` parsing to a Hash with `metadata.generator == 'ruly'`. Refuse a non-empty dir without that marker (`Thor::Error`, exit 1), including in dry-run. Also skip `prepare_output(output_file)` for this target: it calls `FileUtils.rm_f`, which is meant for a file.

### Pitfall 4: Plugin agents silently drop hooks, MCP servers and permissionMode
Docs: "For security reasons, plugin subagents don't support the `hooks`, `mcpServers`, or `permissionMode` frontmatter fields." [CITED: sub-agents.md]. The validator stays silent about them [VERIFIED: probe]. The parent recipe's hooks already go to `hooks/hooks.json`, and `merge_mcp_servers` already adds subagent servers to the recipe list [VERIFIED: cli.rb `merge_mcp_servers`]. So drop the keys from agent frontmatter and name `permissionMode` in the skipped notice. Hooks merged from a subagent's `append`+`cwd` repo config (`RepoConfigReader`) cannot be carried. Name them in the notice too.

### Pitfall 5: MCP secrets copied into a distributable directory
The user's `~/.config/ruly/mcp.json` has 12 servers. 8 of them carry literal (non-`${...}`) `env` values (e.g. `permit` 6, `plane` 3, `teams` 3) [VERIFIED: key/count scan, values not printed]. The plugin `.mcp.json` would hold those literals, and a plugin is meant to be shared. **Avoid:** print a warning naming each server (names only) that has literal `env`/`headers` values. Add a README note: use `${VAR}` references before sharing. Docs say the validator warns on "a header value that looks like a literal credential" [CITED: plugins-reference].

### Pitfall 6: Version pinning with `version = ruly gem version`
"Setting it pins the plugin to that version until you change it" [CITED: plugins-reference]. Re-squashed rules under the same gem version will not update a git-hosted marketplace install. They do update for `--plugin-dir` and local-path marketplaces, which load in place [CITED: loading.md]. Publishing is deferred, so keep the locked decision and add one README line about the limitation.

### Pitfall 7: Nested skill names
`derive_skill_name` keeps subpaths after `/skills/`. For remote superpowers skills like `.../skills/test-driven-development/SKILL.md` it yields `test-driven-development/SKILL` [VERIFIED: script_manager.rb:22-28 + recipe entries in the user's recipes.yml]. The plugin layout documents "One `<name>/SKILL.md` per skill" [CITED: plugins-reference]. Whether nested dirs under `skills/` load in a plugin is not documented, and the validator does not report on them [VERIFIED: probe]. **Avoid:** for the plugin target, flatten the name: strip a trailing `/SKILL`, then replace remaining `/` with `-`. Warn on collisions.

### Pitfall 8: Recipe skill or command names collide with `<recipe>-rules`
A recipe skill named `<recipe>-rules` would overwrite the body skill. Detect it and raise `Ruly::Error`.

### Pitfall 9: Array (agent) recipes and no-recipe mode
`determine_output_file` maps Array recipes to `.claude/agents/<name>.md` [VERIFIED: squash_helpers.rb:113-125]. `-a claude-plugin` without a recipe has no plugin name. **Avoid:** raise `Thor::Error` for both ("claude-plugin target requires a Hash recipe").

### Pitfall 10: `post_squash` budget
`post_squash` is at CyclomaticComplexity 15/15 [CITED: 04-01-PLAN.md baseline], and cli.rb is 566 lines mid-Phase 4 against `Metrics/ClassLength` Max 500 [VERIFIED: .rubocop.yml:76-77 `Metrics/ClassLength:` / `Max: 500`]. Note: ClassLength counts code lines only, so the raw line count overstates it. Re-measure with `bundle exec rubocop lib/ruly/cli.rb --only Metrics/ClassLength` after Phase 4 lands. Put logic in the service and keep CLI additions to about 25 lines.

## Code Examples

### plugin.json written by ruly
```json
{
  "name": "demo",
  "version": "0.3.0",
  "description": "AGENTS.md target fixture",
  "metadata": { "generator": "ruly", "recipe": "demo" }
}
```
`metadata` is the ownership marker. Claude Code doesn't read it [CITED: plugins-reference]. The value comes from `Ruly::VERSION`, which is `'0.2.0'` at lib/ruly/version.rb:4. Phase 4's 04-02 plans a bump to 0.3.0, so read the constant at runtime and never hard-code it. Optional: `"author": {"name": <git config user.name>}` mirrors `claude plugin init` ("--author <name> Author name (default: git config user.name)" [VERIFIED: `claude plugin init --help`]) and makes `--strict` pass. Only include it if the planner wants strict validation, because it is outside the locked field list.

### hooks/hooks.json
```json
{
  "hooks": {
    "WorktreeCreate": [
      { "hooks": [ { "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/worktree-create.sh\"", "timeout": 120, "type": "command" } ] }
    ]
  }
}
```

### Plugin agent frontmatter (plugin mode)
```yaml
---
name: helper
description: Subagent fixture
tools: Bash, Read, Write, Edit, Glob, Grep
model: inherit
skills: [deploy]
---
```
Today's writer emits `skills` as the string `"[a, b]"` via `"[#{...join(', ')}]"` [VERIFIED: subagent_processor.rb:305-306]. Plugin mode should emit a YAML list. How a plugin agent's `skills` entry names a skill from the same plugin (bare `deploy` or `demo:deploy`) is not documented. See Open Questions.

### Notice
```
ℹ️  Claude Code plugins cannot carry always-on instructions; rules were written as skill /<recipe>:<recipe>-rules. For always-on rules run `ruly squash <recipe>` (CLAUDE.local.md).
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `commands/` | `skills/` preferred ("Prefer `skills/` for new plugins") | current docs | Keep commands for existing recipe commands; no conversion needed |
| Top-level `themes`/`monitors` keys | `experimental.*` | current docs | Not used by ruly |
| Agent `permissionMode`/`hooks`/`mcpServers` | Ignored for plugin agents | current docs | Must move to plugin-level files |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Nested `skills/a/b/SKILL.md` does not load in a plugin, so flattening is required | Pitfall 7 | Flattening still works either way. Only slash-command names differ |
| A2 | `${VAR}` env references in a plugin `.mcp.json` expand from the user's environment like a project `.mcp.json` | Pitfall 5 | README advice would be wrong; the secret-literal warning still stands |
| A3 | A plugin agent's `skills:` entry references same-plugin skills by bare name | Code Examples | Preloaded skills fail to resolve in subagents. A one-session `--plugin-dir` check settles it |
| A4 | Commands under a `debug/` subdirectory are fine in plugins (ruly warns for `.claude/commands/debug/`) | Mapping | Cosmetic. Keep the existing warning |

## Open Questions

1. **Skill references inside plugin agents (A3)**
   - Known: the `skills` field preloads full skill content; plugin skills are namespaced `<plugin>:<name>`.
   - Unclear: whether a bare name resolves to the same plugin's skill.
   - Recommendation: emit bare names (matches today) and add a `checkpoint:human-verify` that runs `claude --plugin-dir DIR` once. If it fails, switch to `<plugin>:<name>`.
2. **Should a short SessionStart nudge be added ("invoke /recipe:recipe-rules first")?**
   - It fits under 10,000 chars and would make the rules skill load near-always.
   - It is outside the locked NO-branch decision, and the user's "minimal design surface" memory argues against it. Recommendation: do not build it; mention it in the README as a manual option.
3. **`clean -a claude-plugin` support**: not in CONTEXT, but required to defuse Pitfall 2. Recommendation: minimal marker-gated routing only.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby | gem | ✓ | 4.0.1 | — |
| Bundler | specs | ✓ | 2.6.9 | — |
| Claude Code CLI (`claude plugin validate`) | optional verify gate | ✓ | 2.1.304 | Skip the gate when `command -v claude` fails; specs do not need it |

**Missing dependencies with no fallback:** none.

## Validation Architecture

Skipped: `workflow.nyquist_validation` is `false` in .planning/config.json. Spec guidance for the planner: unit specs for `ClaudePlugin` (output_dir, generated?, manifest fields, hook rewrite, name flattening, skipped notice) and CLI specs on a fixture with skills, commands, hooks, mcp_servers and a subagent. Phase 4's `spec/fixtures/agents_md/` already has all of these (`demo` + `helper` recipes). Stub `MCPManager.load_mcp_servers_from_config` or point HOME at a tmpdir so the real `~/.config/ruly/mcp.json` is never read. Optional e2e gate: `command -v claude >/dev/null && claude plugin validate "$D/proj/ruly-plugin-demo"` exits 0.

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | Validate recipe name as a plugin name (no `/`, `..`, `:`, spaces; reject reserved `claude-*` prefixes up front); flatten skill names; reject `..` in generated paths |
| V6 Cryptography | no | — |
| V8 Data Protection | yes | Warn on literal secrets copied into `.mcp.json` (Pitfall 5) |

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `-o DIR` wipe of a user directory | Tampering | Marker-gated wipe/clean (`metadata.generator == 'ruly'`), refuse otherwise |
| Path traversal via recipe/skill names | Tampering | Name validation + `File.expand_path` containment check under DIR |
| Credential leak via shared plugin `.mcp.json` | Information disclosure | Names-only warning + README guidance |
| Agents claiming `bypassPermissions` | Elevation (misleading) | Drop the key in plugin mode (it is ignored by Claude Code anyway) |

## Project Constraints (from CLAUDE.md)

- README must be updated for CLI changes (`-a claude-plugin`, `-o DIR`, notice, always-on finding).
- Never edit `CLAUDE.local.md`. Never edit `rules/` (submodule) for this phase.
- Test `ruly squash` from a temp dir (`mktemp -d`), never from the project directory. Point HOME at a temp dir in e2e checks.
- Services are `module_function`. Use keyword args for optional params. RuboCop: line length 120, ClassLength 500, MethodLength 30, CyclomaticComplexity 15, `Obsession/MethodOrder` (callee below caller).
- Use `git mv` for moves. Do not stage `Gemfile.lock` (unrelated local platform change).
- After changes, the installed ruly binary must be updated, and README slash-command/CLI sections kept current.

## Sources

### Primary (HIGH confidence)
- https://code.claude.com/docs/en/plugins-reference (manifest reference: fields, standard layout, CLAUDE.md note, env vars, validate). Accessed 2026-11-02
- https://code.claude.com/docs/en/plugins/components.md (skills, commands, plugin agent frontmatter, hooks, MCP, default settings)
- https://code.claude.com/docs/en/hooks.md (SessionStart, additionalContext, 10,000-char cap, exec/shell form)
- https://code.claude.com/docs/en/sub-agents.md (frontmatter table, plugin restrictions, `--agent` replaces system prompt)
- https://code.claude.com/docs/en/output-styles.md (`force-for-plugin`, `keep-coding-instructions`)
- https://code.claude.com/docs/en/skills.md (frontmatter, 1,536-char cap, 500-line advice, compaction budget)
- https://code.claude.com/docs/en/memory.md (no third-party plugin route)
- https://code.claude.com/docs/en/plugins/marketplace-reference.md, https://code.claude.com/docs/en/plugins/loading.md
- Local: `claude plugin validate` / `--strict` / `--json` probes, `claude --help`, `claude plugin init --help` (Claude Code 2.1.304)
- Codebase: lib/ruly/cli.rb (commit 166c8e8), services/{subagent_processor,settings_manager,mcp_manager,script_manager,squash_helpers,source_processor,agents_md}.rb, 04-01-PLAN.md

### Secondary / Tertiary
- None. No web-search-only claims.

## Metadata

**Confidence breakdown:**
- Always-on verdict: HIGH. Explicit doc text plus validator warning reproduced locally.
- Plugin layout/schema: HIGH. Docs plus a passing local validation of a ruly-shaped probe.
- Ruly integration points: HIGH. Read in source this session. Note that Phase 4 is still landing on this branch, so re-read cli.rb before planning tasks.
- Pitfalls 7/A1-A3: MEDIUM/LOW, as marked.

**Research date:** 2026-11-02
**Valid until:** 2026-11-16 (Claude Code plugin docs change weekly; re-run `claude plugin validate --help` at execution)
