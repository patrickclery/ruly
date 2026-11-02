---
phase: 05-claude-code-plugin-packaging
reviewed: 2026-11-02T05:05:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - CHANGELOG.md
  - README.md
  - lib/ruly/cli.rb
  - lib/ruly/services.rb
  - lib/ruly/services/claude_plugin.rb
  - lib/ruly/services/display.rb
  - lib/ruly/services/script_manager.rb
  - lib/ruly/services/source_processor.rb
  - lib/ruly/services/subagent_processor.rb
  - lib/ruly/version.rb
  - spec/fixtures/claude_plugin/.recipes.yml
  - spec/fixtures/claude_plugin/rules/base.md
  - spec/fixtures/claude_plugin/rules/commands/ship.md
  - spec/fixtures/claude_plugin/rules/demo.md
  - spec/fixtures/claude_plugin/rules/scripts/notify.sh
  - spec/fixtures/claude_plugin/rules/skills/deploy.md
  - spec/fixtures/claude_plugin/rules/skills/review.md
  - spec/fixtures/claude_plugin/rules/skills/tdd/SKILL.md
  - spec/ruly/claude_plugin_spec.rb
  - spec/ruly/cli_claude_plugin_spec.rb
  - spec/ruly/subagent_plugin_mode_spec.rb
findings:
  critical: 2
  warning: 7
  info: 7
  total: 16
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-11-02T05:05:00Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

I reviewed the `-a claude-plugin` target: `ClaudePlugin` service, CLI wiring, subagent/skill/command/script
plumbing, specs and docs. The 136 phase specs pass. I ran the fixture end to end with an isolated HOME
in a scratch directory and reproduced the key findings.

The two blockers:
1. **The working-directory guard can be bypassed.** It compares paths as strings rather than resolved
   filesystem paths. Reproduced: with a symlinked `-o "$PWD"`, squash wiped the working directory and
   then crashed.
2. **Subagent skills skip all name checks.** One silently overwrote the generated `RECIPE-rules`
   skill. Reproduced.

The warnings cover:
- Validation that runs only after the plugin directory has been wiped.
- Hook rewriting that runs in the wrong order and ignores quoting.
- MCP secret detection that misses `args` and `url`.
- Safety warnings that disappear when Ruby warnings are turned off.
- Subagent names that are not checked for path traversal.
- A plugin version pinned to the ruly gem version.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: The cwd/parent/HOME guard can be bypassed through symlinks and `//`, so squash and clean can wipe the working directory

**File:** `lib/ruly/services/claude_plugin.rb:120-124` (used at `:107`, `:130-131`, `:407`)
**Issue:** `dangerous?` builds the target path with `File.expand_path(dir)`, which only tidies the string and does not resolve symlinks. It then compares that to `Dir.pwd`, which is the real filesystem path from `getcwd`. Any symlinked path to the working directory gets past the check, for example `-o "$PWD"` after `cd`-ing through a symlink, or anything under `/tmp` on macOS (`/tmp` is `/private/tmp`). `File.expand_path('//')` returns `"//"`, so `-o //` and `-o //home/me` also get past the `/` and `$HOME` checks.

After that, the only protection left is the ownership marker. That fails in the most likely case: a user working inside the plugin directory they generated. Reproduced:
- In `scratchpad/lnk/ruly-plugin-demo`, a symlink to a generated plugin holding `rules/` and `.recipes.yml`, I ran `ruly squash demo -a claude-plugin -o "$PWD"`.
- `reset_dir` deleted the whole working directory: `rules/` and `.recipes.yml` were gone.
- It then recreated an empty directory at that path and crashed with `Errno::ENOENT - getcwd` (stack trace, not a Thor error).
- `ruly clean -a claude-plugin -o "$PWD"` lists the working directory for removal in the same way.

Two related defects:
- `File.expand_path` expands `~`, but the filesystem calls use the literal string. So the guard checks `$HOME/x` while ruly writes to `./~/x`.
- `-o '~nouser'` raises `ArgumentError`. `claude_plugin_dir!` does not catch it, so the user gets a raw stack trace.

**Fix:** Compare resolved filesystem paths, not strings:
```ruby
def dangerous?(dir)
  path = physical(File.absolute_path(dir))          # absolute_path: no ~ expansion
  cwd  = File.realpath(Dir.pwd)
  home = physical(Dir.home)
  path == '/' || path == cwd || path == home || cwd.start_with?("#{path}/")
end

# realpath of the longest existing ancestor + the remaining segments
def physical(path)
  File.realpath(path)
rescue Errno::ENOENT
  File.join(physical(File.dirname(path)), File.basename(path))
end
```
Also check `File.realpath(dir) != File.realpath(Dir.pwd)` again inside `reset_dir` just before `rm_rf`, and add specs for a symlinked working directory, `//` and `~user`.

### CR-02: Subagent skills skip all plugin skill-name checks and can silently overwrite the rules skill

**File:** `lib/ruly/services/subagent_processor.rb:228-235`, `lib/ruly/services/script_manager.rb:402-406`, `lib/ruly/services/claude_plugin.rb:177-209`
**Issue:** `check_paths!` and `check_skill_names!` see only the top-level `skill_files`. Subagent skills are saved later through `save_agent_skills` and are written straight to `File.join(DIR/skills, flat_skill_name(path))` with no checks. Reproduced: adding `rules/skills/demo-rules.md` to the `helper` subagent's `skills:` replaced `ruly-plugin-demo/skills/demo-rules/SKILL.md` (the whole squashed rule set) with the subagent skill's body. There was no error or warning, and the run reported success. The same gap means:
- A subagent skill that collides with a top-level skill overwrites it silently (no "last one wins" warning).
- A skill file named `...md` flattens to `..`, so its `SKILL.md` is written to `DIR/SKILL.md`.
**Fix:** Run the skill-name check over the combined set of top-level and all subagent skills before writing anything. Alternatively, make `save_skill_files(skills_dir:)` refuse unsafe or reserved names and a name that is already present:
```ruby
# in save_agent_skills (plugin mode)
ClaudePlugin.check_skill_names!(deps[:all_skill_files] + skill_files, plugin_name) # raise on rules-skill/unsafe; warn on dup
```
The check must raise `Ruly::Error` outside the `rescue StandardError` in `generate_agent_file` (line 221). Otherwise the collision only becomes a "Could not generate agent file" warning.

## Warnings

### WR-01: Validation runs after the previous plugin has already been wiped

**File:** `lib/ruly/cli.rb:78-83`, `lib/ruly/services/claude_plugin.rb:129-134,226`
**Issue:** `prepare_output` → `reset_dir` deletes the existing plugin directory before these checks run: `process_squash_sources`, `validate_squash_dispatches` and `ClaudePlugin.write` → `check_paths!`. So any skill collision, unsafe name, escaping command path or bad dispatch destroys a working plugin and leaves only the marker file plus the copied `scripts/`. Reproduced with a top-level `demo-rules` skill: exit 1, and the directory then held only `.claude-plugin/plugin.json` and `scripts/notify.sh`. The spec `leaves a dir ruly owns, so a re-run without the skill succeeds` locks this behaviour in.
**Fix:** Process sources first without copying, run `check_paths!` and the dispatch validation, and only then `reset_dir` and copy the bin files. Alternatively, build into a sibling temp directory and `File.rename` it into place once it succeeds.

### WR-02: Hook commands that point at subagent scripts are never rewritten, and the warning they trigger is wrong

**File:** `lib/ruly/cli.rb:513-517`, `lib/ruly/services/claude_plugin.rb:238,285-287`
**Issue:** `write_hooks` runs inside `ClaudePlugin.write`, before `process_subagents`. The subagents' `scripts:` files are only copied into `DIR/scripts` later. Because `copied_script?` checks the filesystem, a hook such as `.claude/scripts/helper.sh` is left unchanged even though `helper.sh` ends up in the plugin. Reproduced: `scripts/` holds `helper.sh`, but `hooks.json` still has `"command": ".claude/scripts/helper.sh"`. It also prints a false "not a recipe script" warning. Markdown is fine only because `rewrite_script_paths` happens to run after the subagents.
**Fix:** Move `write_hooks` (and `write_mcp`) so they run after `process_subagents`, next to `rewrite_script_paths`.

### WR-03: The hook rewrite ignores quoting and misses common script-reference forms

**File:** `lib/ruly/services/claude_plugin.rb:34-38,273-282`
**Issue:** Results observed:
- `bash -c ".claude/scripts/a.sh --x"` becomes `bash -c ""${CLAUDE_PLUGIN_ROOT}/scripts/a.sh" --x"`. The inserted quotes close the outer string, so the expansion is unquoted and breaks on paths with spaces (e.g. a `--plugin-dir` under "Application Support").
- `sh -c '.claude/scripts/a.sh'` becomes `'"${CLAUDE_PLUGIN_ROOT}/…"'`, which passes literal quote characters inside single quotes.
- `"$CLAUDE_PROJECT_DIR"/.claude/scripts/a.sh`, `$CLAUDE_PROJECT_DIR/.claude/scripts/a.sh` (the form Claude Code documents for hooks) and `./.claude/scripts/a.sh` are left unchanged with no warning. The lookbehind excludes `/` and `.`, and the warning only fires on a regex match. The plugin then quietly runs whatever exists in the user's project, or nothing.
**Fix:** Also match the optional `$CLAUDE_PROJECT_DIR/`, `"$CLAUDE_PROJECT_DIR"/` and `./` prefixes and rewrite them. Insert quotes only when the reference is not already inside a quoted string (or emit `${CLAUDE_PLUGIN_ROOT}` without adding quotes when inside one). Warn whenever a command still contains `.claude/scripts/` after the rewrite.

### WR-04: MCP secret detection misses `args` and `url`, so tokens ship without warning

**File:** `lib/ruly/services/claude_plugin.rb:32,306-316`
**Issue:** Only `env` and `headers` are checked. Reproduced: a server with `"args": ["grafana-mcp","--token","glsa_SECRET123"]` is copied verbatim into `ruly-plugin-demo/.mcp.json`, and nothing warns about the args. The same applies to `url` values with credentials (`https://u:p@host`, `?api_key=…`), a common setup for HTTP/SSE servers. The target exists to be shared, so this leaks credentials.
**Fix:** Also flag `args` entries that look like secrets (long tokens, or values after `--token`/`--key`/`--api-key`/`--password`, or `KEY=VALUE` with a secret-like key). Also flag `url` with userinfo or credential-looking query parameters. Better still, warn about every server whose config holds any literal outside `command`/`type`, unless it uses `${VAR}`.

### WR-05: Safety warnings use `Kernel#warn` and vanish when Ruby warnings are off

**File:** `lib/ruly/services/claude_plugin.rb:204,278,302,403,408,415`
**Issue:** `Kernel#warn` does nothing when `$VERBOSE` is nil (`ruby -W0`, `RUBYOPT=-W0`). Users who set that flag to hide noise like the bundler `Gem::Platform` warnings (present in this environment) lose all of these:
- the literal-secret notice
- the skill-collision notice
- the unrewritten-hook notice
- the clean refusal and skip reasons

Confirmed: under `-W0` the hook warning was not printed.
**Fix:** Use `$stderr.puts` for these user-facing notices.

### WR-06: Subagent agent names are not checked for path traversal

**File:** `lib/ruly/services/subagent_processor.rb:78,189`
**Issue:** `agent_file = File.join(agents_dir(plugin_dir), "#{agent_name}.md")` takes `subagent['name']` straight from the recipe, which may come from a `remotes:` repo mirrored by `--sync`. A name like `../../../x` writes outside the plugin directory. Skills and commands get containment checks (`check_paths!`); agents get none, which is inconsistent with the phase's path-safety goal.
**Fix:** In `check_paths!`, check every `subagents[].name` against `NAME_PATTERN` (no `/`, no `..`) before writing, and raise `Ruly::Error`.

### WR-07: The manifest version is pinned to the ruly gem version, so shared plugins never update

**File:** `lib/ruly/services/claude_plugin.rb:150`
**Issue:** `'version' => Ruly::VERSION` gives every plugin the version `0.4.0`, whatever the rule content. Claude Code caches marketplace and git installs by version, so re-squashed rules never reach anyone who installed the shared plugin until the ruly gem itself is released again. The README admits this (lines 799-802), but it defeats the target's "share" use case.
**Fix:** Take the version from a recipe `version:` key when present. Otherwise use `Ruly::VERSION` plus a short content hash of the generated files (e.g. `0.4.0+a1b2c3d`, or bump the patch number from a hash).

## Info

### IN-01: The plugin and rules-skill names allow characters that Claude Code skill names forbid
**File:** `lib/ruly/services/claude_plugin.rb:26,166`
**Issue:** `NAME_PATTERN` accepts uppercase letters, `.` and `_`, with no length limit. The skill name `RECIPE-rules` must be lowercase letters, digits and hyphens, at most 64 characters, so a recipe such as `WorkAxle_core` produces a rules skill that may fail to load.
**Fix:** Refuse such names, or convert them to lowercase kebab-case for the plugin/skill name, and cap the length at 64 characters.

### IN-02: `--deepclean` with `-a claude-plugin` deletes project files and leaves the plugin directory
**File:** `lib/ruly/cli.rb:258-259,528`
**Issue:** `clean demo -a claude-plugin --deepclean` lists `.claude/` and a user-written `CLAUDE.md` for removal (reproduced) and leaves `ruly-plugin-demo/` alone. The README documents this, but it contradicts the target's "never touches the project" promise.
**Fix:** Have deepclean with this target also include the plugin directory, or print a warning naming the project files it will delete.

### IN-03: The rules-skill table of contents leaks absolute local paths and leaves out plugin commands
**File:** `lib/ruly/services/claude_plugin.rb:361`
**Issue:** With `-t`, anchors for `requires:` sources contain the absolute path (e.g. `#tmp-…-scratchpad-e2e-rules-base-base-rule`), which puts the user's home path into a plugin meant for sharing. `generate_toc_content` lists slash commands only when the agent is `'claude'`.
**Fix:** Build anchors from paths relative to the rules root, and pass the commands for the plugin target.

### IN-04: `-i`/`-I` write absolute or `../` `-o` paths verbatim into `.gitignore`
**File:** `lib/ruly/cli.rb:518`
**Fix:** Write a pattern only when the directory is inside the repository, and make it relative to the repository root.

### IN-05: The plugin's `.mcp.json` ignores the project's legacy `mcp.yml`, unlike the claude target
**File:** `lib/ruly/services/claude_plugin.rb:293-295` vs `lib/ruly/services/mcp_manager.rb:72-77`
**Fix:** Merge it the same way, or note the difference in the README.

### IN-06: Subagent command files are dropped silently
**File:** `lib/ruly/services/subagent_processor.rb:190`
**Issue:** `command_files` is assigned but never used (RuboCop `Lint/UselessAssignment`). `save_subagent_commands` is unused, so a subagent recipe's `commands:` never reach the plugin, and the skipped-parts notice does not mention it. RuboCop also reports new ordering offenses in the touched lines: `subagent_processor.rb:34`, `:216`.
**Fix:** Write them to `DIR/commands/<agent>/`, or add `subagent commands` to `skipped_parts`.

### IN-07: The specs miss the edge cases above
**File:** `spec/ruly/claude_plugin_spec.rb`, `spec/ruly/cli_claude_plugin_spec.rb`
**Issue:** There are no specs for:
- a symlinked or physical-path working directory, `//` or `~user`
- subagent skill collisions or unsafe subagent skill names
- hooks that reference subagent scripts
- secrets in `args`/`url`
- quoted hook contexts
- traversal in agent names

`leaves a dir ruly owns…` locks in the wipe-before-validate behaviour from WR-01.

---

_Reviewed: 2026-11-02T05:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
