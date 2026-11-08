---
phase: 08-project-to-recipe-generator-skill
reviewed: 2026-11-08T07:41:08Z
depth: standard
iteration: 3
files_reviewed: 2
files_reviewed_list:
  - skills/recipe-from-project.md
  - README.md
findings:
  critical: 1
  warning: 0
  info: 8
  total: 9
status: issues_found
---

# Phase 8: Code Review Report (iteration 3)

**Reviewed:** 2026-11-08T07:41:08Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

This pass re-checks the iter-2 fixes (b5448d9, 6aa6520, 3729eee) in `skills/recipe-from-project.md`. README lines 892-920 have not changed since iter 2. Everything ran in the session scratchpad under a temp `HOME`, using a git-initialised scratch rules clone at `$TMPHOME/github.com/patrickclery/rules`. That way the skill's default `RULES` pointed at the scratch clone. The real rules clone and `~/.config/ruly/` were not read or changed.

| Iter-2 finding | Status | Evidence |
| --- | --- | --- |
| CR-01 (fold turns skills and commands into rules) | **holds, including the agent's behaviour** | Two headless agent runs below. The Step 8 skill and command check also catches the bad fold. |
| WR-01 (`body-differs` loss not reported) | holds | The prose now says the next squash overwrites the copy, and Step 6 lists it as a loss. |
| WR-02 (`CLAUDE.md`/`.cursor/rules` gave `no-evidence`) | **fixed, but it adds a regression** | See CR-01 below. |

### Agent-behaviour evidence for the iter-2 CR-01 fix

**Setup.** The scratch clone has `tag/a.md` and `tag/b.md`, whose bodies are over 200 characters, plus `tag/skills/tag-skill.md` (`name: tag-skill`) and `tag/commands/tagcmd.md`. Recipe `orig` is `files: [tag/a.md, tag/b.md]`, `skills: [tag/skills/tag-skill.md]` and `commands: [tag/commands/tagcmd.md]`. `ruly squash orig` in `$TMPHOME/proj/tagproj` wrote `CLAUDE.local.md`, `.claude/skills/tag-skill/SKILL.md`, `.claude/commands/tag/tagcmd.md` and `.mcp.json`. The exact-match block printed `exact-name` (skill), `exact-body` (command), and `exact-rule` for `tag/a.md` and `tag/b.md`. Every `.md` under `tag/` matched, which is the case that triggered the old fold.

**Skill install.** The current `skills/recipe-from-project.md` was copied to `$TMPHOME/run/.claude/skills/recipe-from-project/SKILL.md`.

**Command (run 1):**
```bash
cd "$TMPHOME/run" && HOME="$TMPHOME" CLAUDE_CONFIG_DIR=/home/patrick/.claude \
  claude -p "/recipe-from-project $TMPHOME/proj/tagproj" \
  --add-dir "$TMPHOME/proj/tagproj" --add-dir "$TMPHOME/github.com/patrickclery/rules" \
  --permission-mode bypassPermissions --disallowedTools Edit Write
```
`CLAUDE_CONFIG_DIR` keeps the subscription login available under the temp `HOME`. `--disallowedTools Edit Write` makes sure the run cannot write to the recipe.

**Observed draft (run 1, verbatim YAML):**
```yaml
tagproj:
  description: "Tag workflow project: release tagging skill, tag command, and two service rules"
  files:
    - tag/a.md
    - tag/b.md
  skills:
    - tag/skills/tag-skill.md
  commands:
    - tag/commands/tagcmd.md
```
All four entries were labelled exact. The report said: "Not folded into `tag/`: that folder also holds the skill and the command, so the two rule files stay listed separately." The draft keeps `skills:` and `commands:`, and nothing was folded into `files: [tag/]`.

**Run 2 (fold still allowed where it is correct).** This layout uses `tag2/rules/{a,b}.md`, `tag2/skills/tag2-skill.md` and `tag2/commands/tag2cmd.md` (recipe `orig2`), squashed into `$TMPHOME/proj/rulesproj`. The command was the same with that path. Observed draft:
```yaml
rulesproj:
  description: "Tag2 release tagging rules, skill and command"
  files:
    - tag2/rules/
  skills:
    - tag2/skills/tag2-skill.md
  commands:
    - tag2/commands/tag2cmd.md
```
The fold went to the highest qualifying directory, `tag2/rules/` and not `tag2/`, and the skill and command were kept. `git status` on the scratch clone was empty after both runs.

**Step 8 check catches the bad fold.** A recipe of `files: [tag/]` plus the same `skills:` and `commands:` entries was run through the validate-recipe block. It printed `exit=0`, `4 rule files combined` and empty findings, with no `Would create skill files` or `Would create command files` sections. The new comparison rule therefore flags both draft entries as failures, as intended.

## Critical Issues

### CR-01: The WR-02 fix stops the evidence check from spotting the tool's own squash in any project with a hand-written `CLAUDE.md`

**File:** `skills/recipe-from-project.md:32-41, 44`
**Issue:** CONTEXT.md requires: "The skill warns when it detects that state" (a `ruly-tools` squash inside the target project). Commit 3729eee added `[ ! -s CLAUDE.md ]` and the empty `.cursor/rules` test to the same AND chain that detects that state. Any project with a non-empty `CLAUDE.md` now always gets `evidence-ok`, even when its `CLAUDE.local.md` and `.mcp.json` were just wiped. Most real projects have one. CONTEXT.md names this ruly repo as the example target, and its `CLAUDE.md` is 18,300 bytes.

Scratch reproduction:
- **Project:** the `tagproj` copy, with the rule-filled `CLAUDE.local.md`, a `teams` MCP server and a hand-written `CLAUDE.md`.
- **Squash:** `ruly squash ruly-tools` ran inside it, with a local skill entry. It left a 0-byte `CLAUDE.local.md`, `"mcpServers": {}` and only `.claude/skills/recipe-from-project/SKILL.md`.
- **Current block:** prints `evidence-ok` in bash and in zsh.
- **Block at 880e2e1:** prints `no-evidence`.

The skill then goes on silently with judgment-only matches against `CLAUDE.md`. Its report says nothing is lost, because `CLAUDE.local.md` is empty and there are no MCP servers. It never says that the evidence was overwritten or that git may recover it. The user can approve a confident draft that drops every rule file and MCP server the project used. The iter-2 false `no-evidence` was a noisy failure. This one is silent, and it disables the only guard for the hazard the README and Anti-patterns warn about.
**Fix:** Detect the clobber signature separately from deciding whether evidence is left. Then warn and ask, rather than collapsing both into one test:
```bash
if [ -f "${PROJECT}/.claude/skills/recipe-from-project/SKILL.md" ] &&
  [ -z "${others}" ] && [ ! -e "${PROJECT}/AGENTS.md" ] &&
  [ -f "${PROJECT}/CLAUDE.local.md" ] && [ ! -s "${PROJECT}/CLAUDE.local.md" ] &&
  [ -f "${PROJECT}/.mcp.json" ] &&
  jq -e '(.mcpServers // {}) | length == 0' "${PROJECT}/.mcp.json" > /dev/null 2>&1; then
  if [ -s "${PROJECT}/CLAUDE.md" ] || [ -n "$(find "${PROJECT}/.cursor/rules" -type f 2>/dev/null | head -1)" ]; then
    echo clobbered-partial
  else
    echo no-evidence
  fi
else
  echo evidence-ok
fi
```
On `clobbered-partial`, say that `CLAUDE.local.md` and `.mcp.json` look overwritten by this tool's own recipe and that git may recover them. Then ask whether to continue with `CLAUDE.md` and `.cursor/rules` only. If the user continues, put that warning at the top of the report. Update example 3 to match.

## Info

### IN-01: The name-check one-liner crashes when `recipes.yml` has no `recipes:` key (carried over, unfixed)

**File:** `skills/recipe-from-project.md:254`
**Fix:** `puts((YAML.safe_load_file(ARGV[0], aliases: true) || {}).fetch("recipes", {}).keys)`

### IN-02: The name check accepts names YAML reads as non-strings, and names starting with `-` (carried over)

**File:** `skills/recipe-from-project.md:257`
**Fix:** Require `\A[A-Za-z][A-Za-z0-9._-]*\z`, and reject `yes`, `no`, `on`, `off`, `true`, `false` and `null`.

### IN-03: url-match skips failed `files:` fetches silently and never collects `commands:` URLs (carried over)

**File:** `skills/recipe-from-project.md:154, 179`
**Fix:** Print an `unfetched-url` row when a fetch fails, and add `'commands' => []` to `urls`.

### IN-04: A nonzero `exit=` is not stated as a failure, and the grep misses `Recipe '...' not found` (carried over)

**File:** `skills/recipe-from-project.md:329, 336`
**Fix:** Say that a nonzero `exit=` is always a failure, and add `not found|No recipes found|Error` to the grep.

### IN-05: The 200-character cutoff for `exact-rule` is not documented (carried over)

**File:** `skills/recipe-from-project.md:127, 133, 180`
**Issue:** A rule with a short body can never be `exact-rule`. Under the new Step 4 rule, its directory can then fold only through a judgment match.
**Fix:** Document the cutoff next to line 133.

### IN-06: The README lists the skill under "Available Ruly Commands" with no note that a recipe must list it first (carried over)

**File:** `README.md:894`
**Fix:** Add "(add to a recipe first, see [Drafting a Recipe From a Project](#drafting-a-recipe-from-a-project))".

### IN-07: "Alphabetical position" does not say which order yalphabetize uses (carried over)

**File:** `skills/recipe-from-project.md:265`
**Fix:** Say "in Ruby string (byte) order: `-` < `.` < digits < uppercase < `_` < lowercase".

### IN-08: The new Step 8 comparison does not say how a source path maps to a dry-run line

**File:** `skills/recipe-from-project.md:336`
**Issue:** `Display#dry_run_skills` and `#dry_run_commands` print derived targets, not the draft's source paths. For example, `tag/skills/tag-skill.md` prints as `.claude/skills/tag-skill/SKILL.md`, and `tag/commands/tagcmd.md` prints as `tag/tagcmd.md` after `omit_command_prefix`. A `skills:` directory entry prints one line per file. An agent comparing literally could report false failures, or miss a real one.
**Fix:** Add: "Map each source with the rule in url-match's `derive` (`.claude/skills/<derived>/SKILL.md`) and Step 6's command-path rule, and expect one line per file for a directory entry."

---

_Reviewed: 2026-11-08T07:41:08Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
