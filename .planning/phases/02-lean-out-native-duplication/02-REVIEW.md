---
phase: 02-lean-out-native-duplication
reviewed: 2026-11-02T09:12:36Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - lib/ruly/cli.rb
  - lib/ruly/operations.rb
  - lib/ruly/operations/stats.rb
  - lib/ruly/services/display.rb
  - lib/ruly/services/mcp_manager.rb
  - lib/ruly/services/recipe_loader.rb
  - lib/ruly/services/squash_helpers.rb
  - lib/ruly/version.rb
  - spec/ruly/cli_essential_spec.rb
  - spec/ruly/cli_front_matter_spec.rb
  - spec/ruly/cli_mcp_spec.rb
  - spec/ruly/cli_removed_options_spec.rb
  - spec/ruly/cli_requires_spec.rb
  - spec/ruly/operations/stats_spec.rb
  - spec/ruly/recipe_key_warnings_spec.rb
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-11-02T09:12:36Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

I reviewed the diff against `66bde3c`. The phase removed `--cache`, the TaskMaster flags, shell_gpt JSON output, `import`, `mcp` and `analyze`, added `check_unknown_options!`, and added warnings for removed or unknown recipe keys.

These checks passed:

- **No dangling references.** Nothing in `lib/`, `bin/`, `spec/` or `README.md` still points at removed code: `Analyzer`, `cached_file_count`, `copy_taskmaster_config`, `write_shell_gpt_json`, `import_dry_run`, `load_mcp_server_definitions`, `write_mcp_json`, `cache_dir` or `contexts.yml`.
- **`KNOWN_RECIPE_KEYS` is complete.** It lists all 14 top-level recipe keys that ruly reads, checked against every `recipe[...]` access in `lib/`.
- **`squash --clean` and `squash --deepclean` still work under `check_unknown_options!`.** Verified by running them in a temporary directory. Thor runs `check_unknown!` on an empty argv for commands started with a hash, and Thor's indifferent-access `slice` keeps `output_file` and `agent`.
- **Removed switches are rejected.** `--cache` now fails with `Unknown switches "--cache"`.
- **Specs.** All 3 failures in the 7 changed spec files are listed in `02-rspec-baseline.txt`.

There are no blockers. The main gaps:

- The new warn-and-continue covers only per-recipe keys. A top-level `tier:`, which the 0.1.0 README documented and the author's own `~/.config/ruly/recipes.yml` still has, is now ignored without a warning.
- `-a sgpt` silently writes Markdown into a `.json` file.
- Two existing CLI problems are now more visible: `stats` aborts when no recipe source is configured, and `squash --help` errors instead of showing help.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Top-level `tier:` in recipes.yml is silently ignored; warn-and-continue covers only per-recipe keys

**File:** `lib/ruly/services/recipe_loader.rb:100-118` (and `:521-545`)
**Issue:** The 0.1.0 README told users to put a global `tier: claude_max` at the top level of `~/.config/ruly/recipes.yml`. The removed `Analyzer#get_tier_for_recipe` read it as `recipes_config['tier']`. `recipe_key_warnings` only checks keys inside each recipe hash. `load_all_recipes` never checks the top-level keys of the user or project config files. A global `tier:` is now dropped with no warning, which goes against this phase's warn-and-continue goal for removed keys. The author's live `~/.config/ruly/recipes.yml` has exactly this: its top-level keys are `["tier", "remotes"]`.
**Fix:** Check the top-level config keys too, for example in `load_all_recipes` after `read_config_file`:
```ruby
KNOWN_CONFIG_KEYS = %w[recipes remotes overrides].freeze

def config_key_warnings(path, config)
  (config.keys.map(&:to_s) - KNOWN_CONFIG_KEYS).map do |key|
    if REMOVED_RECIPE_KEYS.include?(key)
      "⚠️  #{path}: '#{key}' was removed in ruly 0.2.0 and is ignored"
    else
      "⚠️  #{path}: unknown key '#{key}' is ignored"
    end
  end
end
```
Call it for `user_config` and `project_config`, or return the messages so the CLI can `warn` them once per run.

### WR-02: `-a sgpt` / `-a shell_gpt` silently writes Markdown into a `.json` role file

**File:** `lib/ruly/cli.rb:234-237` (spec: `spec/ruly/cli_removed_options_spec.rb:69-90`)
**Issue:** Before 0.2.0, `normalize_agent` mapped `sgpt` to `shell_gpt` and the squash wrote a JSON role file. That branch is gone, so both names now fall through as an unknown agent. A user running `ruly squash -a sgpt -o ~/.config/shell_gpt/roles/x.json` gets plain Markdown in a `.json` path, with exit 0 and no message. Shell-GPT then fails to parse the role. The new spec asserts this silent behaviour (`JSON.parse` raises). It is inconsistent with the stderr warnings this phase added for removed recipe keys and the hard errors it added for removed switches.
**Fix:** Warn, or fail, on the removed agent:
```ruby
REMOVED_AGENTS = %w[sgpt shell_gpt].freeze

def normalize_agent(agent)
  warn "⚠️  agent '#{agent}' (shell_gpt JSON output) was removed in ruly 0.2.0; writing markdown" if REMOVED_AGENTS.include?(agent)
  agent = 'claude' if agent&.downcase&.gsub(/[^a-z]/, '') == 'claudecode'
  agent
end
```
Then update the spec to expect the stderr warning.

### WR-03: `recipes_for_stats` rescues the wrong exception, so `ruly stats` aborts when no recipe source exists

**File:** `lib/ruly/cli.rb:453-458` (with `:263-268`)
**Issue:** `recipes_for_stats` is documented as "nil when no recipe source is configured" and rescues `Ruly::Error`. But it calls the CLI wrapper `load_all_recipes`, which already converts `Ruly::Error` into `Thor::Error`, so the rescue never fires. Verified: with no recipe config, `ruly stats` prints "📊 Analyzing 1 files...", then "❌ No recipes found…", exits, and never writes `stats.md`. The bug existed before this phase. It matters more now because `stats` is the only remaining token-analysis command after `analyze` was folded into it.
**Fix:**
```ruby
def recipes_for_stats
  Services::RecipeLoader.load_all_recipes(sync: sync_requested?, user_recipes_file: recipes_file)
rescue Ruly::Error
  nil
end
```

### WR-04: `check_unknown_options!` turns `ruly <cmd> --help` / `-h` into an error

**File:** `lib/ruly/cli.rb:17`
**Issue:** With strict option checking, `ruly squash --help`, `ruly squash -h` and `ruly stats --help` now fail with `Unknown switches "--help"` and exit 1. At `66bde3c`, `squash --help` silently ran a real squash, which was worse, so this is an improvement. Users still get an error instead of the help text Thor can produce with `ruly help squash`.
**Fix:** Rewrite per-command help flags before dispatch:
```ruby
def self.start(given_args = ARGV, config = {})
  if given_args.size >= 2 && (given_args & %w[-h --help]).any? && all_commands.key?(given_args.first.tr('-', '_'))
    given_args = ['help', given_args.first]
  end
  super
end
```
Add a spec next to the "kept switches" context in `cli_removed_options_spec.rb`.

## Info

### IN-01: `cache` is listed as a "removed" recipe key but was never a recipe key

**File:** `lib/ruly/services/recipe_loader.rb:527`
**Issue:** At `66bde3c`, `cache` was only a CLI switch: `cached?` ignored `_recipe_config`, and the README never documented `cache:` inside a recipe. The warning "'cache' was removed in ruly 0.2.0" is therefore inaccurate, since a recipe `cache:` key was ignored before as well.
**Fix:** Use `REMOVED_RECIPE_KEYS = %w[tier].freeze` so that `cache` gets the generic "unknown key" warning. Alternatively, keep it and word the message for both cases.

### IN-02: Keys inherited through `extends:` are reported under each child recipe's name

**File:** `lib/ruly/services/recipe_loader.rb:599-611`, `lib/ruly/cli.rb:250-257`
**Issue:** `merge_recipe!` copies every parent key the child lacks, including unknown or removed ones such as `tier`. Each child that extends a parent with `tier:` then warns `Recipe '<child>': 'tier' was removed…`, but the key is not in the child's definition. That points the user at the wrong place to fix.
**Fix:** Record the recipe that each unknown key came from before `resolve_extends!`. A simpler option is to run `recipe_key_warnings` over the raw recipes once in `load_all_recipes`, before `extends` and `overrides` are merged.

### IN-03: `Display.squash_dry_run` keeps a dead `_recipe_name` parameter

**File:** `lib/ruly/services/display.rb:13-14`, `lib/ruly/cli.rb:64-65`
**Issue:** The only use of `recipe_name` was the removed "Would cache output" line. The method still takes 10 positional parameters behind a `Metrics/ParameterLists` disable.
**Fix:** Remove the parameter and the matching argument at the call site.

### IN-04: The removed-commands spec does not cover `analyze`

**File:** `spec/ruly/cli_removed_options_spec.rb:95`
**Issue:** The spec checks only `import` and `mcp`, although `analyze` was also removed.
**Fix:** Use `%w[import mcp analyze].each do |command|`.

### IN-05: `Operations::Stats.display_result` calls `exit 1` from the operations layer

**File:** `lib/ruly/operations/stats.rb:17-29`
**Issue:** This code moved unchanged from `Analyzer.display_stats_result`. Library code that prints and calls `Kernel#exit` goes against the project's error-handling convention (`Thor::Error` for CLI-level failures) and makes the class hard to reuse.
**Fix:** Have `display_result` return a boolean, or raise. Let `CLI#stats` decide the exit, for example with `raise Thor::Error, "❌ Error: #{result[:error]}"`.

---

_Reviewed: 2026-11-02T09:12:36Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
