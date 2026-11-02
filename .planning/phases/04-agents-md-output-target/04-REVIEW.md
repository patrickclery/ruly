---
phase: 04-agents-md-output-target
reviewed: 2026-11-02T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - lib/ruly/cli.rb
  - lib/ruly/services.rb
  - lib/ruly/services/agents_md.rb
  - lib/ruly/services/display.rb
  - lib/ruly/services/squash_helpers.rb
  - lib/ruly/version.rb
  - ruly.gemspec
  - README.md
  - CHANGELOG.md
  - spec/ruly/agents_md_spec.rb
  - spec/ruly/cli_agents_md_spec.rb
  - spec/fixtures/agents_md/.recipes.yml
  - spec/fixtures/agents_md/rules/skills/deploy.md
  - spec/fixtures/agents_md/rules/demo.md
findings:
  critical: 2
  warning: 4
  info: 5
  total: 11
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-11-02
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Reviewed the `-a agents` target (AgentsMd service, CLI wiring, marker-gated clean, overwrite guard, git ignore handling, shared `write_sources`), the 0.3.0 version/gemspec change, README/CHANGELOG, and the two new spec files. The 39 phase-04 examples pass. Claude/cursor output parity is preserved: `write_sources` is a verbatim extraction of the old loop. The marker check handles CRLF correctly. BOM, leading whitespace and empty files are refused, which fails safe.

Two defects were reproduced in a scratch directory with an isolated HOME:
1. `-a agents -i` un-ignores `CLAUDE.local.md` and `.claude/commands/`, and the reverse also happens.
2. Skill heading demotion breaks on valid nested or mixed fences. It rewrites lines inside code blocks and leaves real headings at h1.

`--deepclean` runs before the overwrite guard, so a refused squash has already deleted the Claude artifacts and the hand-written `CLAUDE.md`. The README's "frontmatter stripped" claim is false for rules that have `name:` or `description:`.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: `-i`/`-I` with `-a agents` replaces the Ruly ignore section, un-ignoring CLAUDE.local.md (and vice versa)

**File:** `lib/ruly/cli.rb:377` (with `lib/ruly/services/git_ignore_manager.rb:61`)
**Issue:** `GitIgnoreManager.update` replaces the whole `# Ruly generated files` section with the current run's patterns. Phase 4 adds a second output target that shares this section. Reproduced:
```
ruly squash demo -i            -> section: CLAUDE.local.md, .claude/commands/
ruly squash demo -a agents -i  -> section: AGENTS.md            (CLAUDE.local.md no longer ignored)
```
Running the claude target with `-i` afterwards un-ignores `AGENTS.md` in the same way. The README tells users with private rule repos to use `-i`/`-I` so that `AGENTS.md` is not committed. Following that advice for one target silently exposes the other target's output to `git add -A`, which is a private-content leak. No spec covers the case where both targets have run.
**Fix:** Merge new patterns into the existing section instead of replacing it:
```ruby
if ruly_section_start
  ...
  kept = existing_lines[(ruly_section_start + 1)...ruly_section_end]
  existing_lines[ruly_section_start...ruly_section_end] = ['# Ruly generated files'] + (kept + patterns).uniq
```
Add a spec that runs `squash demo -i` and then `squash demo -a agents -i`, and asserts that both `CLAUDE.local.md` and `AGENTS.md` remain in `.gitignore`.

### CR-02: Fence tracking in `demote_headings` corrupts code blocks and skips real headings

**File:** `lib/ruly/services/agents_md.rb:18,102-113`
**Issue:** `FENCE = /\A\s*(```|~~~)/` toggles state on any fence-like line. It ignores the fence character, the fence length, and whether the line is a 4-space indented code line. Reproduced:
- ````` ````md ````` that contains a ```` ```bash ```` block: the inner ```` ``` ```` toggles state "out", so `# x` inside the code is rewritten to `### x`. Code examples in AGENTS.md change.
- A `~~~` block that contains ```` ``` ````: the next `~~~` re-opens the fence, so the real `# After` heading after the block stays h1 inside `## Skills` and breaks the hierarchy.
- An indented `    ```` ` (an indented code line, not a fence) also toggles state.

Skills that document markdown, which ruly's own rules do heavily, routinely nest fences.
**Fix:** Track the opening fence and close only on a matching fence. Per CommonMark, the closing fence uses the same character, is at least as long, has at most 3 spaces of indent, and has no info string:
```ruby
FENCE = /\A {0,3}(`{3,}|~{3,})(.*)\z/
def demote_headings(text)
  open = nil
  text.each_line.map do |line|
    if (m = line.chomp.match(FENCE))
      if open.nil? then open = m[1]; next line
      elsif m[1][0] == open[0] && m[1].length >= open.length && m[2].strip.empty? then open = nil; next line
      end
    end
    next line if open || !(match = line.chomp.match(HEADING))
    ...
```
Add specs for nested 4-backtick fences, `~~~` containing ```` ``` ````, and indented fence lines.

## Warnings

### WR-01: `--deepclean` runs before the overwrite guard, so a refused squash has already deleted files

**File:** `lib/ruly/cli.rb:57,68`
**Issue:** `invoke_clean_if_requested` (line 57) runs before `guard_agents_md_output!` (line 68). Reproduced with a hand-written `AGENTS.md` and `CLAUDE.md` and the command `ruly squash demo -a agents --deepclean`:
1. `.claude/`, `CLAUDE.local.md`, the user's `CLAUDE.md` and `.mcp.json` are deleted.
2. The guard then refuses and nothing is written.

The user loses files and gets no output.
**Fix:** Resolve `output_file` and call `guard_agents_md_output!` before `invoke_clean_if_requested`. This needs `load_sources` first, or a recipe-independent guard on `AgentsMd.output_file(options[:output_file], agent)`. A refused run must have no side effects.

### WR-02: The agents target writes `.claude/scripts/` and rewrites references to it

**File:** `lib/ruly/cli.rb:378` (with `lib/ruly/services/toc_generator.rb:194`)
**Issue:** `write_agents_md` calls `ScriptManager.copy_scripts`, which writes to `.claude/scripts/`. `rewrite_script_references` points AGENTS.md at `.claude/scripts/<name>`. This contradicts the stated contract ("no Claude-only artifacts", "leaves `.claude/` alone"):
- `clean -a agents` never removes these scripts.
- `-i`/`-I` do not ignore them.
- The dry-run and summary say nothing agents-specific about them.

The spec "writes no Claude-only artifacts" passes only because the fixture declares no `scripts:`.
**Fix:** Either list `scripts` in `skipped_parts` and do not copy or rewrite them for the agents target, or add the script directory to the agents ignore patterns and to `agents_md_files_to_clean`, and document it. Add a fixture rule with `scripts:` frontmatter to the spec.

### WR-03: `name:`/`description:` frontmatter leaks into AGENTS.md, contrary to the README

**File:** `lib/ruly/services/agents_md.rb:89` (body path), `README.md:716-717`
**Issue:** By default, `FrontmatterParser.strip_metadata` keeps `name`/`description`/`permissionMode`/`allowed_tools` frontmatter. Rule bodies therefore land in AGENTS.md as `---\ndescription: Base rules\n---` (reproduced). Generic markdown renders that as a thematic break plus a setext h2 "description: Base rules". Skills are run through `FRONTMATTER` stripping and rules are not, so the file is inconsistent. The README states "frontmatter stripped".
**Fix:** In `AgentsMd.write`, strip leading frontmatter from each local source before writing. Map it as `local_sources.map { |s| s.merge(content: s[:content].sub(FRONTMATTER, '')) }`, keeping the original `:content` for the post-squash checks. Alternatively, correct the README.

### WR-04: The parity spec does not compare against the claude target

**File:** `spec/ruly/cli_agents_md_spec.rb:11,59-61`
**Issue:** "writes the same body the claude target gets" compares the output with a hard-coded string, including an accidental double blank line. A future change to claude output, or to the shared `write_sources`, would not be caught, so the parity guarantee is untested. The suite also has no specs for:
- nested or mixed fences (CR-02),
- running both targets with `-i` (CR-01),
- deepclean with the guard (WR-01),
- scripts (WR-02),
- marker edge cases: CRLF, BOM, empty file.
**Fix:** Run `squash demo -a claude` and `squash demo -a agents` in the same temp dir. Assert `agents.lines.drop(2).join == File.read('CLAUDE.local.md')` up to the `## Skills` section. Add the missing edge-case examples.

## Info

### IN-01: Marker check is rigid and `-o CLAUDE.local.md` is silently ignored

**File:** `lib/ruly/services/agents_md.rb:25-30,36-42`
**Issue:**
- An empty `AGENTS.md`, or a ruly-generated one that an editor re-saved with a UTF-8 BOM or leading whitespace, is refused as "not generated by ruly". This fails safe, but the error is confusing (for example, after `touch AGENTS.md`). Consider treating a zero-byte file as overwritable and stripping a leading `﻿` before `start_with?`.
- `-a agents -o CLAUDE.local.md` is indistinguishable from the Thor default and writes `AGENTS.md`, while `-o ./CLAUDE.local.md` is honored.
- `gets` with no limit reads an entire newline-free file. Use `gets(nil, 256)` or `read(MARKER.bytesize)`.

### IN-02: Post-squash checks run on raw skills, not on the AGENTS.md actually written

**File:** `lib/ruly/cli.rb:379`
**Issue:** `Checks.run_all(local_sources + skill_files, ...)` checks unrendered skill content. The `## Skills` heading and the prepended `### <skill-name>` headings are never seen, so collisions with them (for example a rule heading "Skills" or "Deploy" plus a link to it) go unreported. The README says the checks run "over the whole AGENTS.md". Pass the rendered skills, plus a synthetic `## Skills` source, to the checks.

### IN-03: Setext headings in skills are not demoted

**File:** `lib/ruly/services/agents_md.rb:19,96-99`
**Issue:** A skill whose title is `Title\n=====` keeps an h1 under `## Skills`. It also gets an extra `### <name>` heading, because the first line does not match `HEADING`. Either document that only ATX headings are supported or convert setext headings.

### IN-04: Cosmetic output and dry-run inaccuracies

**File:** `lib/ruly/services/agents_md.rb:64`, `lib/ruly/services/display.rb:19`
**Issue:** The header is followed by two blank lines, because `io.puts` adds one and the body already starts with `\n`, and the spec locks that in. The dry-run "Output size" excludes the header and the inlined skills for the agents target.

### IN-05: `CLAUDE.local.md` default duplicated in three places

**File:** `lib/ruly/services/agents_md.rb:15`, `lib/ruly/services/squash_helpers.rb:690`, `lib/ruly/cli.rb:37`
**Issue:** `AgentsMd.output_file` depends on the Thor default string matching `CLAUDE_DEFAULT_OUTPUT`. Define one constant, for example `SquashHelpers::DEFAULT_OUTPUT`, and reference it from all three places.

---

_Reviewed: 2026-11-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
