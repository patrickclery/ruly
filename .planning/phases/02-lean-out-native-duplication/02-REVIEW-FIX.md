---
phase: 02-lean-out-native-duplication
fixed_at: 2026-11-02T09:18:35Z
review_path: .planning/phases/02-lean-out-native-duplication/02-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 2: Code Review Fix Report

**Fixed at:** 2026-11-02
**Source review:** .planning/phases/02-lean-out-native-duplication/02-REVIEW.md
**Iteration:** 1

**Summary:**

- Findings in scope: 5 (WR-01 to WR-04, plus IN-01 by request)
- Fixed: 5
- Skipped: 0
- Left as-is (out of scope): IN-02, IN-03, IN-04, IN-05

## Fixed Issues

### WR-01: Top-level `tier:` in recipes.yml is silently ignored

**Files modified:** `lib/ruly/services/recipe_loader.rb`, `lib/ruly/cli.rb`,
`spec/ruly/recipe_key_warnings_spec.rb`, `README.md`, `CHANGELOG.md`, `AUDIT.md`
**Commit:** 1e82b54
**Applied fix:** Added `REMOVED_CONFIG_KEYS = %w[tier]` and `RecipeLoader.config_key_warnings(path,
config)`. `load_all_recipes` records the warnings for the user and project files, and the CLI prints
each one once per run on stderr: `<file>: 'tier' was removed in ruly 0.2.0 and is ignored`. Only
the key name is printed, never the value. Other unknown top-level keys are not warned, per the
guidance.

### WR-02: `-a sgpt` / `-a shell_gpt` silently writes Markdown into a `.json` file

**Files modified:** `lib/ruly/cli.rb`, `spec/ruly/cli_removed_options_spec.rb`, `CHANGELOG.md`,
`AUDIT.md`
**Commit:** 3b783fa
**Applied fix:** `normalize_agent` prints a one-line stderr notice for `sgpt` and `shell_gpt` (case
insensitive): `Agent '<name>': shell_gpt JSON output was removed in ruly 0.2.0; writing markdown
instead`. Markdown output is unchanged. The spec now asserts the notice and checks that
`claudecode` normalizes without a notice.

### WR-03: `ruly stats` aborts when no recipe source exists

**Files modified:** `lib/ruly/cli.rb`, `spec/ruly/cli_stats_spec.rb` (new), `README.md`,
`CHANGELOG.md`
**Commit:** 14dc125
**Applied fix:** Moved the loading into a new helper, `load_recipes_and_warn`, which raises
`Ruly::Error`. `load_all_recipes` still turns that into `Thor::Error`. `recipes_for_stats` now calls
the helper directly, so its `rescue Ruly::Error` works. It prints one stderr line, `Recipes not
loaded, so recipe totals are skipped: No recipes found.`, and returns nil, so `stats.md` is still
written for the local files. The stderr line also stops real config errors, such as circular
`extends`, from being hidden. Checked by hand with an empty `HOME`: exit 0 and `stats.md` written.

### WR-04: `ruly <cmd> --help` / `-h` errors with "Unknown switches"

**Files modified:** `lib/ruly/cli.rb`, `spec/ruly/cli_removed_options_spec.rb`, `README.md`,
`CHANGELOG.md`
**Commit:** 434997b
**Applied fix:** Overrode `CLI.start` to rewrite `<cmd> ... -h|--help` to `help <cmd>`. It only
looks at arguments before `--`, and only when the first argument is not a flag. Thor's built-in
`map HELP_MAPPINGS => :help` covers only a leading flag, so `ruly -h` behaves as before.
`check_unknown_options!` still applies, so `squash --cache` still fails. New specs cover `squash
--help`, `squash -h`, `squash core --help` and `stats --help`, and check that no output file is
written. Checked by hand: `ruly squash --help`, `ruly stats -h` and `ruly list-recipes --help` print
usage.

### IN-01: `cache` listed as a removed recipe key

**Files modified:** `lib/ruly/services/recipe_loader.rb`, `spec/ruly/recipe_key_warnings_spec.rb`,
`CHANGELOG.md`, `AUDIT.md`
**Commit:** b64ced5
**Applied fix:** Changed `REMOVED_RECIPE_KEYS` to `%w[tier]`, so a recipe `cache:` now gets the
generic "unknown key" warning. Added a spec for this. Updated the CHANGELOG example and the AUDIT
row. The 0.1.0 README did have one example comment, "if recipe has cache: true", but no code ever
read the key, so the AUDIT row now says that.

## Verification

- Ran in the main checkout on `gsd/competitive-positioning`, not in a worktree. The parent told me
  to stay on this branch, and the user's run is idle. All commands ran in this tree and can be
  reproduced from it.
- `bundle exec rspec`: 507 examples, 15 failures, 1 pending. Every failure, compared by full
  description, is in `02-rspec-baseline.txt`. There are no new failures.
- `bundle exec rubocop lib spec`: 177 offenses before and after. The only offense in a touched lib
  file, `Obsession/MethodOrder` at `cli.rb` `invoke_clean_if_requested`, was there before. The new
  `spec/ruly/cli_stats_spec.rb` has no offenses.
- `Gemfile.lock` was not staged. No hooks ran: `core.hooksPath` points at a directory with no
  pre-commit hook.

---

_Fixed: 2026-11-02_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
