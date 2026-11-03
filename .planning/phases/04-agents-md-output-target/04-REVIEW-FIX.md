---
phase: 04-agents-md-output-target
fixed_at: 2026-11-02T00:00:00Z
review_path: .planning/phases/04-agents-md-output-target/04-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 4: Code Review Fix Report

**Fixed at:** 2026-11-02
**Source review:** .planning/phases/04-agents-md-output-target/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (CR-01, CR-02, WR-01, WR-02, WR-03, WR-04, IN-01 BOM handling only)
- Fixed: 7
- Skipped: 0
- Out of scope, untouched: IN-01 (empty-file refusal, `-o CLAUDE.local.md`, unbounded `gets`), IN-02, IN-03, IN-04, IN-05

## Fixed Issues

### CR-01: `-i`/`-I` with `-a agents` replaces the Ruly ignore section

**Files modified:** `lib/ruly/services/git_ignore_manager.rb`, `spec/ruly/cli_agents_md_spec.rb`, `spec/ruly/cli_spec.rb`, `README.md`, `CHANGELOG.md`
**Commit:** ec1de39
**Applied fix:** `GitIgnoreManager.update` merges into an existing `# Ruly generated files` section. Existing entries come first, then the new ones, deduplicated. First-run output (no section yet) is unchanged. New specs cover claude then agents, agents then claude, and a repeated run, each for both `-i` and `-I`. The two existing `cli_spec` examples "replaces existing Ruly section" asserted the old replace behavior. They are renamed to "merges new patterns into the existing Ruly section" and now assert `old-file.md` / `old.md` stays. This is a deliberate behavior change: stale entries are no longer pruned. It is documented in the CHANGELOG under 0.3.0 Changed.

### CR-02: Fence tracking in `demote_headings` corrupts code blocks

**Files modified:** `lib/ruly/services/agents_md.rb`, `spec/ruly/agents_md_spec.rb`
**Commit:** bdf7469
**Applied fix:** Fence handling now follows CommonMark. `FENCE = /\A {0,3}(`{3,}|~{3,})(.*)\z/` matches a fence line. `fence_toggles?` opens a block on any fence, except a backtick fence whose info string contains a backtick. It closes a block only on the same character, a run at least as long as the opener, and nothing but whitespace after it. New specs: a 3-backtick block nested in a ````md fence, a `~~~` block containing a backtick fence, the length rule, an info-string non-closer, 3-space indent with a trailing-space closer, a 4-space-indented non-fence, and a backtick info string containing a backtick.

### WR-01: `--deepclean` runs before the overwrite guard

**Files modified:** `lib/ruly/cli.rb`, `spec/ruly/cli_agents_md_spec.rb`, `README.md`, `CHANGELOG.md`
**Commit:** a2e6956
**Applied fix:** In `squash`, `invoke_clean_if_requested` now runs right after `guard_agents_md_output!`, after sources load and the output path resolves. A refused run deletes nothing. The specs use `--clean` and `--deepclean` against a hand-written `AGENTS.md` with `CLAUDE.md`, `CLAUDE.local.md`, `.mcp.json` and `.claude/keep.txt` present. Each run must exit 1 and every file must survive. For all targets, clean now runs after recipe loading. The claude/cursor output files are unchanged (differential gate).

### WR-02: The agents target writes `.claude/scripts/` without ignoring or documenting it

**Files modified:** `lib/ruly/cli.rb`, `lib/ruly/services/agents_md.rb`, `spec/ruly/cli_agents_md_spec.rb`, `spec/ruly/agents_md_spec.rb`, `README.md`, `CHANGELOG.md`
**Commit:** c68896f
**Applied fix:** This is the minimal fix the orchestrator specified. A new `AgentsMd.script_ignore_patterns(script_files)` returns one `.claude/scripts/NAME` per copied local or remote script. `update_git_ignores` takes `extra_patterns:`, and only `write_agents_md` passes it. The claude ignore patterns are unchanged: the claude target does not ignore scripts today, so for the agents target this follows the per-path style of claude's `.claude/commands/` entry. `clean -a agents` still keeps scripts, because claude has no equivalent marker-safe rule. The README documents that scripts are copied to `.claude/scripts/` for both targets, that `-i`/`-I` ignore them for the agents target, and that `--deepclean` removes them. The specs edit the fixture's `demo.md` in place to add `scripts:` and cover the copy, the rewritten reference, both ignore flags, and clean keeping the script.

### WR-03: `name:`/`description:` frontmatter leaks into AGENTS.md

**Files modified:** `lib/ruly/services/agents_md.rb`, `lib/ruly/cli.rb`, `spec/ruly/cli_agents_md_spec.rb`, `spec/ruly/agents_md_spec.rb`, `README.md`, `CHANGELOG.md`
**Commit:** 02bc5c2
**Applied fix:** I reproduced the claude target keeping the same `---\nname: base\ndescription: Base rules\n---` block in `CLAUDE.local.md`. `FrontmatterParser.strip_metadata` does this deliberately to preserve Claude Code directives, so the claude behavior is not a bug and stays byte-identical. A new `AgentsMd.rule_body` splits the leading frontmatter off processed rule content the same way `strip_metadata` does, so the AGENTS.md body matches what claude writes for a rule without directives. `AgentsMd.write` applies it unless `--front-matter` is given (new `keep_frontmatter:` keyword). Post-squash checks still receive the original sources. Specs: AGENTS.md has no directives while CLAUDE.local.md keeps them, `--front-matter` keeps them, and `rule_body` unit cases.

### WR-04: Parity spec does not compare against the claude target

**Files modified:** `spec/ruly/cli_agents_md_spec.rb`, `spec/ruly/agents_md_spec.rb`
**Commit:** 15a826d
**Applied fix:** The hard-coded `claude_body` is removed. The parity example squashes the fixture for `-a claude` and `-a agents` in the same temp dir and asserts that the AGENTS.md text after the header, up to `\n## Skills\n`, equals `CLAUDE.local.md` exactly. Added marker edge cases: CRLF header (true), empty file (false), marker not on line 1 (false). The other missing specs listed in the finding landed with their fixes: nested fences (CR-02), both targets with `-i` (CR-01), deepclean with the guard (WR-01), scripts (WR-02), BOM (IN-01).

### IN-01: Marker check is rigid (BOM handling only)

**Files modified:** `lib/ruly/services/agents_md.rb`, `spec/ruly/agents_md_spec.rb`, `README.md`, `CHANGELOG.md`
**Commit:** c34f4ad
**Applied fix:** `generated?` reads line 1 with `File.open(path, 'r:BOM|UTF-8', &:gets)`, so a leading UTF-8 BOM is dropped before the `start_with?(MARKER)` check. Empty-file refusal is unchanged, as instructed. Specs: a BOM plus the header gives true, and a BOM plus a hand-written heading gives false.

## Verification

All gates ran in the **main checkout** (`workflow.use_worktrees` opt-out per the orchestrator; no worktree was created), at HEAD c34f4ad.

- `bundle exec rspec`: 577 examples, 15 failures, 1 pending. Every failing full description is in `.planning/phases/02-lean-out-native-duplication/02-rspec-baseline.txt` (pre-fix run: 546 examples, the same 15).
- RuboCop on the touched Ruby files (`lib/ruly/cli.rb`, `lib/ruly/services/agents_md.rb`, `lib/ruly/services/git_ignore_manager.rb`, `spec/ruly/cli_agents_md_spec.rb`, `spec/ruly/agents_md_spec.rb`, `spec/ruly/cli_spec.rb`): 1 offense, the same count as before. It is the pre-existing `Obsession/MethodOrder` warning in `cli.rb`. Because WR-01 changed the call order in `squash`, the warning now names `normalize_agent` instead of `invoke_clean_if_requested`. No other offenses.
- Differential gate (04-01-PLAN.md command, run against `git archive 996098c`): `-a claude`, `-a cursor` and `-a claude -t` on the phase-04 fixture are byte-identical (timestamp line excluded) after every commit.
- `Gemfile.lock` was never staged. No stash, reset or checkout was used. CLAUDE.md, CLAUDE.local.md and rules/ were not touched.

---

_Fixed: 2026-11-02_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
