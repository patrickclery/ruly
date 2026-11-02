---
phase: 05-claude-code-plugin-packaging
fixed_at: 2026-11-02T05:40:00Z
review_path: .planning/phases/05-claude-code-plugin-packaging/05-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 8
skipped: 1
status: partial
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-11-02T05:40:00Z
**Source review:** .planning/phases/05-claude-code-plugin-packaging/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 9 (CR-01, CR-02, WR-01 to WR-07; T-05-13 = CR-02; the unregistered
  subagent-name traversal flag = WR-06)
- Fixed: 8
- Skipped: 1 (WR-07, documented as a known limitation as instructed)

Fixes were made and committed in the main checkout on `gsd/competitive-positioning`, with no
worktree, as instructed. All gates below also ran in the main checkout.

## Fixed Issues

### Preparatory refactor (no finding)

**Files modified:** `lib/ruly/cli.rb`, `lib/ruly/services/mcp_manager.rb`
**Commit:** 6b0980e
**Applied fix:** Moved `CLI#merge_mcp_servers` into `MCPManager.merge_recipe_servers`. The CLI
method is now a one-line delegator. This brought cli.rb from 498/500 to 481/500 code lines, so the
fixes had room under `Metrics/ClassLength`. Output is unchanged.

### CR-01: The cwd/parent/HOME guard can be bypassed through symlinks and `//`

**Files modified:** `lib/ruly/services/claude_plugin.rb`, `spec/ruly/claude_plugin_spec.rb`,
`spec/ruly/cli_claude_plugin_spec.rb`
**Commit:** df948f7
**Applied fix:**
- `dangerous?` now compares `File.realpath` results, which resolves symlinks and collapses `//`.
  It checks the plugin dir against the realpath of the cwd and its parents, of `Dir.home`, and of
  `/`.
- A path that does not exist cannot be any of those, so it is allowed.
- If the cwd or home directory cannot be resolved, the dir is refused.
- A new `refusal_reason` refuses any `-o` that starts with `~`. ruly never expands it, so `~nouser`
  now gives a clean Thor error (exit 1) instead of an `ArgumentError` backtrace.
- `clean` uses the same reason.
- `reset_dir` still re-guards before `rm_rf`.
- Specs cover: a symlinked cwd, a symlinked parent of the cwd, a symlinked `$HOME`, `//`, `//.`,
  `//HOME`, `~`, `~nouser` and `~/plug`, plus e2e squash and clean through a symlinked working
  directory.

### CR-02 / T-05-13: Subagent skills skip all plugin skill-name checks

**Files modified:** `lib/ruly/services/claude_plugin.rb`, `lib/ruly/services/subagent_processor.rb`,
`lib/ruly/cli.rb`, `spec/ruly/claude_plugin_spec.rb`, `spec/ruly/cli_claude_plugin_spec.rb`
**Commit:** c06bc53
**Applied fix:**
- `check_skill_names!` now takes the set of skills already claimed in the plugin. In plugin mode,
  `SubagentProcessor.save_agent_skills` checks each subagent's skills before writing them. The
  claimed set is the recipe skills, passed in as `plugin_skills:`, plus the skills of earlier
  subagents.
- A skill name is refused if it does not match `NAME_PATTERN`, contains `..`, or is the generated
  `RECIPE-rules` skill. Recipe skills now use the same rule; it was `.`/`..`/empty before.
- In plugin mode, a `Ruly::Error` from a subagent is now re-raised instead of becoming a "Could not
  generate agent file" warning. The claude target keeps the warning.
- A name that another source file already holds gives the existing "both map to plugin skill …;
  the last one wins" warning. This matches the recipe-skill rule and the reviewer's suggested fix;
  it is not an error.

### WR-01: Validation runs after the previous plugin has already been wiped

**Files modified:** `lib/ruly/cli.rb`, `lib/ruly/services/claude_plugin.rb`,
`spec/ruly/claude_plugin_spec.rb`, `spec/ruly/cli_claude_plugin_spec.rb`
**Commit:** d485777
**Applied fix:**
- `prepare_output` no longer resets the plugin dir.
- Plugin bin files are no longer copied while the sources are processed (`dry_run` is on for the
  plugin agent).
- The recipe skill/command `check_paths!` and the dispatch validation run before any write.
- `ClaudePlugin.write` builds inside a new `replace_dir`. It moves the previous plugin to a hidden
  `.DIR.ruly-previous-PID-TIME` sibling and then builds a fresh dir with the marker. When the build
  succeeds it deletes the backup. When the build raises or is interrupted (an `ensure` block), it
  puts the backup back.
- So failures inside the subagent build (CR-02 collisions, nested-subagent errors) also keep the
  previous plugin.
- The spec "leaves a dir ruly owns, so a re-run without the skill succeeds" was replaced by:
  - "writes nothing on a first run"
  - "keeps the previous plugin untouched" (byte-for-byte snapshot)
  - "when a subagent fails the build … keeps the previous plugin and leaves no backup behind"
  - `.replace_dir` unit specs.

### WR-02: Hook commands that point at subagent scripts are never rewritten

**Files modified:** `lib/ruly/services/claude_plugin.rb`, `spec/ruly/cli_claude_plugin_spec.rb`
**Commit:** 1bb09b3
**Applied fix:** `write_hooks` and `write_mcp` now run after the block that writes the recipe skills
and subagents, next to `rewrite_script_paths`. `DIR/scripts` therefore holds every script by the
time hooks are rewritten, and the false "not a recipe script" warning is gone. An e2e spec adds a
subagent `scripts:` file that a parent hook references. It expects the hook to be rewritten with no
stderr output.

### WR-03: The hook rewrite ignores quoting and misses common script-reference forms

**Files modified:** `lib/ruly/services/claude_plugin.rb`, `spec/ruly/claude_plugin_spec.rb`
**Commit:** b6405cb
**Applied fix:**
- `hook_command` tracks shell quote state with `quote_after`, honoring backslash escapes outside
  single quotes.
- A reference inside a single- or double-quoted string becomes a bare
  `${CLAUDE_PLUGIN_ROOT}/scripts/X`. An unquoted reference is double-quoted, as before.
- The new `HOOK_SCRIPT_REF` also matches these prefixes: `./`, `$CLAUDE_PROJECT_DIR/`,
  `${CLAUDE_PROJECT_DIR}/`, `"$CLAUDE_PROJECT_DIR"/` and `"${CLAUDE_PROJECT_DIR}"/`.
- Every `.claude/scripts/` reference left unmatched is named on stderr ("… which is outside the
  plugin; left unchanged"), for example `~/.claude/scripts/X` and `$HOME/.claude/scripts/X`.
- Specs cover 8 rewrite forms, including `bash -c "…"`, `sh -c '…'` and escaped inner quotes, and 2
  kept-with-warning forms.
- **Requires human verification:** inside `sh -c '…'` the rewrite is a bare `${CLAUDE_PLUGIN_ROOT}`.
  This follows the reviewer's "no added quotes inside a quoted string" rule. The inner shell then
  word-splits a plugin root that contains spaces. Confirm this trade-off is acceptable.

### WR-04: MCP secret detection misses `args` and `url`

**Files modified:** `lib/ruly/services/claude_plugin.rb`, `spec/ruly/claude_plugin_spec.rb`,
`spec/ruly/cli_claude_plugin_spec.rb`
**Commit:** a821f06
**Applied fix:** `literal_secret_servers` still flags any literal `env`/`headers` value. It now also
flags:
- `args` with a literal after a credential flag (`--token X`, `--password X`).
- A credential `--flag=X` or `KEY=X` arg.
- A token-shaped literal: a known prefix such as `ghp_`, `glsa_`, `sk-`, `xoxb-` or `AKIA`, or a
  word of 32+ characters mixing letters and digits.
- A `url` with literal userinfo or a credential query parameter.

`${VAR}` values are never flagged. Only server names are printed. The notice now reads "has literal
values that may be secrets (env, headers, args or url) for: NAMES". Specs cover positive and
negative args/url cases, and check that the token value is never printed. **Requires human
verification:** the heuristics can false-positive, for example on a `--no-auth` flag followed by a
literal value.

### WR-05: Safety warnings use `Kernel#warn` and vanish when Ruby warnings are off

**Files modified:** `lib/ruly/services/claude_plugin.rb`, `spec/ruly/claude_plugin_spec.rb`
**Commit:** 831114c
**Applied fix:**
- All ClaudePlugin notices now go through `ClaudePlugin.alert`, which calls
  `$stderr.write("#{message}\n")`. This covers the skill collision, hook, unmatched hook ref,
  MCP-secret, clean refusal, skip and "pass RECIPE" notices.
- `$stderr.write` was used instead of `$stderr.puts` because RuboCop `Style/StderrPuts` rejects
  `$stderr.puts`. The behavior is the same and no disable comment is needed.
- Message text is unchanged.
- A spec runs the notices with `$VERBOSE = nil`.

### WR-06: Subagent agent names are not checked for path traversal (also the unregistered flag)

**Files modified:** `lib/ruly/cli.rb`, `lib/ruly/services/subagent_processor.rb`,
`spec/ruly/cli_claude_plugin_spec.rb`, `spec/ruly/subagent_plugin_mode_spec.rb`
**Commit:** 3f18772
**Applied fix:**
- New `SubagentProcessor.validate_agent_names!` checks each `subagents[].name` with
  `ClaudePlugin.safe_name?` (`NAME_PATTERN`, no `..`).
- It is called from a new `CLI#guard_output!`, which replaces `claude_plugin_dir!` and also runs
  the agents-output guard.
- It runs before clean and before any write, dry run included, for every target except `agents`.
  It raises a Thor error (exit 1).
- Specs cover the claude target, the plugin target and the plugin dry run: each exits 1 and the
  project tree is unchanged.
- This is a user-visible change for the claude and cursor targets, so it is listed under CHANGELOG
  0.4.0 `### Changed`. The existing user recipes were scanned and none has an invalid subagent
  name.

### Docs (README / CHANGELOG)

**Files modified:** `README.md`, `CHANGELOG.md`
**Commit:** 4163185
**Applied fix:**
- README "Claude Code Plugin Output" now documents: the quote-aware hook rewrite and its forms,
  subagent scripts, the args/url secret heuristics, the symlink and `~` guards, the
  keep-previous-plugin build, and the skill and subagent name rules.
- It also has a new "Known limitation: `version`" bullet (WR-07) with the manual workaround.
- The CHANGELOG 0.4.0 entry gains the same items, a `### Changed` entry (subagent name check) and a
  `### Known limitations` entry. Both files are prettier-clean.

## Skipped Issues

### WR-07: The manifest version is pinned to the ruly gem version

**File:** `lib/ruly/services/claude_plugin.rb:150`
**Reason:** Skipped by orchestrator instruction. It is recorded as a known limitation in the README
(Claude Code Plugin Output section) and in CHANGELOG 0.4.0 `### Known limitations`. Code is
unchanged.
**Original issue:** `'version' => Ruly::VERSION` gives every plugin the gem version. Claude Code
caches marketplace and git installs by version, so re-squashed rules never reach users who
installed the plugin until ruly itself is released again.

## Verification

All gates ran in the **main checkout** (`/home/patrick/github.com/patrickclery/ruly`), with an
isolated HOME for CLI runs.

- `bundle exec rspec`: 773 examples, 15 failures, 1 pending. All 15 failures match
  `02-rspec-baseline.txt` by full description, so there are no new failures. The baseline before
  the fixes was 713 examples.
- RuboCop, compared with b66376a per touched file: cli.rb 1→1, claude_plugin.rb 0→0,
  subagent_processor.rb 8→7 (the `Lint/UselessAssignment` from IN-06 is gone), mcp_manager.rb 0→0,
  script_manager.rb 8→8, source_processor.rb 0→0, and all 3 phase specs 0→0.
- cli.rb `Metrics/ClassLength` is 484/500.
- Differential gate against c0895d7^: claude, cursor, claude -t and agents output on the agents_md
  fixture, and claude on the claude_plugin fixture, are all byte-identical.
- `claude plugin validate --strict` on the fixture plugin: ✔ Validation passed (read-only).
- Manual e2e runs reproduced the reviewer's scenarios:
  - squash `-o "$PWD"` through a symlinked cwd is refused and the cwd is intact.
  - A subagent `demo-rules` skill under `RUBYOPT=-W0` exits 1 with the collision message, and the
    previous plugin is byte-identical afterwards.

## Notes for the developer

- Stdout ordering changed slightly for `-a claude-plugin`: the "Copied N script files" line now
  appears after the always-on notice, because bin files are copied during the build. The claude,
  cursor and agents targets are unaffected.
- An interrupted plugin build can leave a hidden `.DIR.ruly-previous-*` sibling holding the old
  plugin. The README names this sibling.
- Gemfile.lock was not staged in any commit. This file is left uncommitted for the orchestrator.

---

_Fixed: 2026-11-02T05:40:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
