# Phase 2 Audit: Keep / Remove / Delegate

**Phase:** 02-lean-out-native-duplication
**Date:** 2026-11-02
**Release:** ruly 0.2.0 (minor bump, hard removal, no deprecation period, D-09)

## Method

The inventory was taken from `bin/ruly help <command>` and the Thor `desc` / `option` declarations in
`lib/ruly/cli.rb`, before Plan 01 (commit `66bde3c`) and after Plan 02 (commit `ca20d39`). Output types
come from the squash/clean code paths (`squash_helpers.rb`, `mcp_manager.rb`, `script_manager.rb`,
`settings_manager.rb`). Recipe keys come from `RecipeLoader::KNOWN_RECIPE_KEYS` and
`REMOVED_RECIPE_KEYS`.

The yardstick is `.planning/research-competitive-2026-11-01.md`. A surface is kept when it serves
rule composition (one of the "Where ruly is ahead" items). It is removed when it is unrelated to
composition. It is delegated when Claude Code already does the job natively (the "Where ruly
duplicates native features" items).

**Verdicts:** `keep` (stays in 0.2.0), `remove` (deleted in 0.2.0), `delegate` (deleted from ruly
because a native Claude Code mechanism covers it).

**Decision IDs** (bullets of `02-CONTEXT.md` `<decisions>`, in document order):

| ID | Decision |
|----|----------|
| D-01 | Remove TaskMaster flags and code |
| D-02 | Remove `ruly import` |
| D-03 | Fold `ruly analyze` into `ruly stats` |
| D-04 | Remove the `ruly mcp` command, keep recipe `mcp_servers:` |
| D-05 | Keep skills/commands/subagents generation into `.claude/` |
| D-06 | Keep recipe `hooks:` and propagation to subagent cwd dirs |
| D-07 | Remove `--cache` and its cache code |
| D-08 | Keep `--toc` and `--essential` |
| D-09 | Hard removal, minor version bump, CHANGELOG entry |
| D-10 | This AUDIT.md deliverable |
| D-11 | Removed or unknown recipe keys warn and continue |
| D-12 | Update README.md and any `site/` docs |
| D-13 | Claude's discretion on non-Claude outputs (cursor, shell_gpt) |

## Commands

| Surface | Verdict | Reason | Native alternative / follow-up |
|---------|---------|--------|--------------------------------|
| `squash [RECIPE]` | keep | Compiles recipe composition into one output; this is ruly's core value | Phase 4 adds an AGENTS.md target; Phase 5 adds plugin packaging |
| `clean [RECIPE]` | keep | Removes ruly's own generated output, which no native tool knows about | - |
| `list-recipes` | keep | Recipe discovery across the remotes, project and user config chain | - |
| `introspect RECIPE SOURCE...` | keep | Recipe authoring: scans directories or GitHub repos into a recipe | - |
| `init` | keep | Writes the starter `~/.config/ruly/recipes.yml` | - |
| `version` | keep | Standard; now prints `Ruly v0.2.0` | - |
| `stats [RECIPE]` | keep | The single token report; absorbed the `analyze` console summary (D-03) | - |
| `help` | keep | Thor built-in | - |
| `analyze [RECIPE]` | remove | D-03: duplicated `stats`. `stats.md` already has per-file and per-recipe token totals, so only the console summary moved over. The context-window percentages were dropped: `--tier`, recipe/config `tier:`, `lib/ruly/contexts.yml` (model tiers dated Dec 2024, stale) | `ruly stats [RECIPE]` |
| `import RECIPE` | remove | D-02: unrelated to composition. `squash` already copies recipe scripts to `.claude/scripts/` | `ruly squash RECIPE` |
| `mcp [SERVERS...]` | delegate | D-04: hand-picking MCP servers into `.mcp.json` duplicates Claude Code's native MCP management. Per-recipe selection stays through recipe `mcp_servers:` | `claude mcp add`; Phase 5 plugin `.mcp.json` |

## Flags

Long forms as `ruly help <command>` prints them. Thor's `--no-<flag>` / `--skip-<flag>` negations
follow their flag's verdict.

| Surface | Verdict | Reason | Native alternative / follow-up |
|---------|---------|--------|--------------------------------|
| squash `--output-file` (`-o`) | keep | Chooses the output path (default `CLAUDE.local.md`) | - |
| squash `--agent` (`-a`) | keep | Target agent; now `claude` and `cursor` (any other name gets plain markdown) | Phase 4 AGENTS.md |
| squash `--cache` | remove | D-07: manual-invalidation cache with no TTL; squash is fast enough that a stale cache costs more than it saves | Re-run `ruly squash` |
| squash `--clean` (`-c`) | keep | Clean before squash; part of the compile cycle | - |
| squash `--deepclean` | keep | Removes all Claude artifacts before squash; needed when recipes change component sets | - |
| squash `--dry-run` (`-d`) | keep | Preview without writing | - |
| squash `--git-ignore` (`-i`) | keep | Adds generated files to `.gitignore` | - |
| squash `--git-exclude` (`-I`) | keep | Adds generated files to `.git/info/exclude` | - |
| squash `--toc` (`-t`) | keep | D-08: table of contents for the squashed body | - |
| squash `--essential` (`-e`) | keep | D-08: essential-only filtering, a composition control | - |
| squash `--taskmaster-config` (`-T`) | remove | D-01: TaskMaster integration is unrelated to rule composition | Configure TaskMaster directly |
| squash `--keep-taskmaster` | remove | D-01: same | - |
| squash `--front-matter` | keep | Keeps frontmatter in output when needed | - |
| squash `--home-override` | keep | Allows squashing into `$HOME` | - |
| squash `--verbose` (`-v`) | keep | Diagnostics | - |
| squash `--strict` | keep | Fails on missing transitive `requires:` sources; reliability of composition | - |
| squash `--sync` | keep | Mirrors remote recipes; sharing across machines is a verified advantage | - |
| clean `--output-file` (`-o`) | keep | Cleans a non-default output path | - |
| clean `--dry-run` (`-d`) | keep | Preview | - |
| clean `--agent` (`-a`) | keep | Matches the squash agent | - |
| clean `--deepclean` | keep | Full artifact removal | - |
| clean `--taskmaster-config` (`-T`) | remove | D-01: clean no longer touches `.taskmaster/` | - |
| list-recipes `--sync` | keep | Same mirror as squash `--sync` | - |
| introspect `--description` (`-d`) | keep | Recipe authoring | - |
| introspect `--output` (`-o`) | keep | Recipe authoring | - |
| introspect `--dry-run` | keep | Preview | - |
| introspect `--relative` | keep | Repo-relative paths, matching the rules-repo `recipes.yml` convention | - |
| stats `--output` (`-o`) | keep | Output path for `stats.md` | - |
| analyze `--tier` (`-p`) | remove | D-03: context-window tier percentages dropped with `analyze` | `ruly stats` totals |
| analyze `--all` (`-a`) | remove | D-03: `stats` with no recipe already covers all recipes | `ruly stats` |
| import `--dry-run` (`-d`) | remove | D-02: command removed | `ruly squash --dry-run` |
| mcp `--append` (`-a`) | delegate | D-04: command removed | `claude mcp add` |
| mcp `--recipe` (`-r`) | delegate | D-04: command removed | recipe `mcp_servers:` + `ruly squash` |
| Unknown switches (global, Thor `check_unknown_options!`) | keep | D-09 hard removal: any undeclared switch on any command now exits 1 with `Unknown switches` instead of being ignored or read as a recipe name. Removed commands exit 1 with `Could not find command` | - |

## Output Types

| Surface | Verdict | Reason | Native alternative / follow-up |
|---------|---------|--------|--------------------------------|
| `CLAUDE.local.md` (or the `-o` path) | keep | The always-loaded squashed body; `@imports` cannot give the same token savings | - |
| `.claude/commands/` | keep | D-05: per-recipe command selection is composition | Phase 5 plugin `commands/` |
| `.claude/skills/<name>/SKILL.md` | keep | D-05: per-recipe skill selection | Phase 5 plugin `skills/` |
| `.claude/agents/<name>.md` (subagents, per-subagent model) | keep | D-05: per-subagent model per recipe is a verified advantage plugins lack | Phase 5 plugin `agents/` |
| `.claude/scripts/` | keep | Recipe scripts copied by squash (replaces `import`) | - |
| `.claude/settings.local.json` (hooks, model, isolate) | keep | D-06: per-recipe hook selection is composition | Phase 5 plugin `hooks/hooks.json` |
| Hooks and scripts propagated to subagent `cwd` dirs | keep | D-06 | - |
| `.mcp.json` from recipe `mcp_servers:` | keep | D-04: per-recipe MCP selection is composition | Phase 5 plugin `.mcp.json` |
| `.mcp.yml` for non-Claude agents | keep | Same selection for agents that read YAML | Re-audit with Phase 4 |
| `-a cursor` markdown output | keep | D-13: only non-Claude target until Phase 4 AGENTS.md lands | Re-audit in Phase 4 |
| shell_gpt role JSON (`-a shell_gpt` / `sgpt`) | remove | D-13: lowest-value adapter; those names now get plain markdown like other non-Claude agents | - |
| `cache/<agent>/<recipe>.md` and `~/.cache/ruly/` | remove | D-07: cache removed | - |
| `.taskmaster/config.json` copy | remove | D-01 | - |
| `.taskmaster/CLAUDE.md` import appended to the output | remove | D-01 | - |
| `.gitignore` and `.git/info/exclude` entries | keep | Keeps generated files out of git | - |
| `stats.md` | keep | Per-file token counts, per-recipe totals, orphaned files, circular `requires:` chains | - |
| `analyze` console report | remove | D-03: summary now printed by `stats` | `ruly stats` |
| `.mcp.json` written by the `mcp` command | delegate | D-04 | `claude mcp add` |
| `~/.config/ruly/recipes.yml` from `init` | keep | Starter config | - |
| Recipe YAML from `introspect` | keep | Recipe authoring | - |

## Recipe Keys (D-11)

Unknown or removed keys print a warning on stderr (key name only, never the value) and squash
continues.

| Surface | Verdict | Reason | Native alternative / follow-up |
|---------|---------|--------|--------------------------------|
| `commands` | keep | Composition | - |
| `description` | keep | Shown by `list-recipes` | - |
| `extends` | keep | Recipe inheritance | - |
| `files` | keep | Core composition | - |
| `hooks` | keep | D-06 | - |
| `isolate` | keep | Settings isolation | - |
| `mcp_servers` | keep | D-04 | - |
| `model` | keep | Per-recipe / per-subagent model | - |
| `omit_command_prefix` | keep | Command naming | - |
| `remote_sources` | keep | Remote composition | - |
| `scripts` | keep | Copied to `.claude/scripts/` | - |
| `skills` | keep | D-05 | - |
| `sources` | keep | Composition | - |
| `subagents` | keep | D-05 | - |
| `tier` | remove | D-03: only `analyze` read it; warns as removed | - |
| `cache` | remove | D-07: documented in README but never read by code; warns as removed | - |
| Any other recipe key | remove | Warns as unknown and is ignored (catches typos such as `omitCommandPrefix`) | - |
| Config-level `recipes:` | keep | Recipe definitions | - |
| Config-level `remotes:` | keep | Sharing across machines | - |
| Config-level `overrides:` | keep | Per-machine additions | - |
| Config-level `tier:` | remove | Inert now and not warned; D-11 covers recipe keys only | Delete by hand |

## Discretion: shell_gpt vs cursor (D-13)

shell_gpt output was a role-JSON dump for a niche CLI. Nothing in it consumed skills, commands,
subagents or MCP config, so it was the lowest-value adapter and the easiest to drop. The `-a
shell_gpt` / `-a sgpt` names still work and now produce the same plain markdown as any other
non-Claude agent. cursor stays because removing it now would leave ruly with no non-Claude target
at all until Phase 4 emits AGENTS.md, the cross-agent standard. Once AGENTS.md ships, cursor should
be re-audited: if Cursor reads AGENTS.md, the cursor adapter becomes a duplicate.

## Docs Scan (D-12)

- `README.md`: updated in Plan 03 Task 2. Removed-feature docs dropped; `ruly stats` and the
  recipe-key warning documented.
- `.claude/ruly-recipes-mcp-patterns.md`: usage example switched from the removed import command to
  `ruly squash`.
- `site/`: scanned with `git grep -n -i -e taskmaster -e 'ruly import' -e 'ruly analyze' -e 'ruly
  mcp' -e '--cache' -e shell_gpt -e sgpt -- site ':!site/package-lock.json'`. Zero references, so no
  site page needed a change.

## Follow-ups (not in this phase)

- Refresh the `.planning/codebase/` maps; they still describe Analyzer, the cache and Shell-GPT.
- `docs/claude-code-proxy.md` is a TaskMaster setup guide; it no longer depends on any ruly CLI flag.
- Recipe `core-debugger` in patrickclery/rules uses the misspelled key `omitCommandPrefix` and now
  warns; it should be `omit_command_prefix`.
- The top-level `tier:` in `~/.config/ruly/recipes.yml` is inert and can be deleted.
- `TODO.md` still mentions an import variant.
