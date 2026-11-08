---
phase: 08-project-to-recipe-generator-skill
fixed_at: 2026-11-08T09:00:00Z
review_path: /home/patrick/github.com/patrickclery/ruly/.planning/phases/08-project-to-recipe-generator-skill/08-REVIEW.md
iteration: 3
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 8: Code Review Fix Report

**Fixed at:** 2026-11-08T09:00:00Z
**Source review:** /home/patrick/github.com/patrickclery/ruly/.planning/phases/08-project-to-recipe-generator-skill/08-REVIEW.md
**Iteration:** 3

**Summary:**
- Findings in scope: 1 (1 critical, 0 warnings; scope critical_warning, so IN-01 to IN-08 are not included)
- Fixed: 1
- Skipped: 0

**Where verification ran:** the edit and commit were made in the isolated worktree (`.claude/worktrees/rf-08-*`, removed afterwards). The commit was fast-forwarded onto `gsd/phase-06-subscription-only`. The checks used scratch fixtures in the session scratchpad (`$T` below): a git-initialised scratch rules clone, a temp `HOME` whose mirror is a symlink to that clone, and scratch project folders. The real rules clone and `~/.config/ruly/` were not changed, `ruly squash` ran only in scratch folders, and `claude` was not run. The scratch clone's `git status` was empty at the end.

## Fixed Issues

### CR-01: The WR-02 fix stops the evidence check from spotting the tool's own squash in any project with a hand-written `CLAUDE.md`

**Files modified:** `skills/recipe-from-project.md`
**Commit:** d070dee
**Applied fix:** The evidence check now asks two separate questions:

- Is the `ruly-tools` mark there? That means this skill, an empty `CLAUDE.local.md`, and a `.mcp.json` with no servers.
- Is anything else left? That means other skills, commands or agents, `AGENTS.md`, a non-empty `CLAUDE.md`, or files under `.cursor/rules`.

Results:

- Mark present and something left: the new `clobbered-partial` result. The prose says to warn that `CLAUDE.local.md` and `.mcp.json` look overwritten and that git may recover them, and to name what is left. It then asks before drafting, and stops without a clear yes. If the user goes on, the warning goes at the top of the report, those two files count as missing rather than empty, and Step 6 says their losses cannot be known.
- Mark present and nothing left: `no-evidence`, as before.
- No mark and nothing in any scanned file: also `no-evidence`, with its own wording ("none of the files Step 2 scans hold anything"). This covers WR-02's empty-project case.
- Anything else: `evidence-ok`.

Example 3 is kept, and a new example covers `clobbered-partial`.

**Change from the review's suggested code:** the review's snippet still had `[ -z "${others}" ]` inside the mark test. In these scratch runs, `ruly squash ruly-tools` did not remove skills or commands that an earlier squash wrote. It also kept the ruly repo's hand-written `.claude/commands`. With that snippet, both the ruly repo copy and `wiped-leftover` would still print `evidence-ok`. The fix therefore treats leftover skills, commands and agents as "something left", not as a reason to drop the mark.

**Status: fixed: requires human verification.** The shell block was checked on every case below. The agent's handling of the new warn-and-ask step is prose, and no headless agent run was made (one would need `CLAUDE_CONFIG_DIR` under a temp `HOME`, which this run was not allowed to use).

#### Fixtures

Commands, with `T=<scratchpad>/it3`, `P=$T/proj` and `R=$T/rules`:

```bash
# Scratch rules clone: tag/a.md, tag/b.md (bodies > 200 chars), tag/skills/tag-skill.md,
# tag/commands/tagcmd.md, tools/skills/recipe-from-project.md (copy of the skill).
# recipes.yml: orig = files [tag/a.md, tag/b.md] + skills + commands + mcp_servers [teams];
#              rulesonly = files [tag/a.md, tag/b.md] + mcp_servers [teams];
#              ruly-tools = skills [tools/skills/recipe-from-project.md] (local, no network).
# $T/home/.config/ruly/mcp.json has a dummy "teams"; $T/home/.config/ruly/remotes/patrickclery/rules -> $R
sq() { (cd "$1" && HOME="$T/home" ruly squash "$2" > /dev/null 2>&1; echo "squash $2 in $(basename "$1"): exit=$?") }
# ruly-copy: this repo's CLAUDE.md (18,300 bytes), .claude/commands, .claude/ruly, .claude/ruly-recipes-mcp-patterns.md
sq "$P/ruly-copy" ruly-tools
sq "$P/fully-wiped" rulesonly; sq "$P/fully-wiped" ruly-tools
sq "$P/wiped-leftover" orig;   sq "$P/wiped-leftover" ruly-tools
sq "$P/tagproj" orig;          sq "$P/tagproj" ruly-tools   # plus a hand-written CLAUDE.md (review's case)
sq "$P/normal" orig
# handwritten: only a hand-written CLAUDE.md. empty: an empty folder.
```

Every squash printed `exit=0`. State afterwards:

| Fixture          | Files left                                                                          | `CLAUDE.local.md` | `.mcp.json`           |
| ---------------- | ----------------------------------------------------------------------------------- | ----------------- | --------------------- |
| `ruly-copy`      | `CLAUDE.md`, hand-written commands and skill, `recipe-from-project/SKILL.md`        | 0 bytes           | `{"mcpServers":{}}`   |
| `fully-wiped`    | `recipe-from-project/SKILL.md` only (`CLAUDE.local.md` was 773 bytes before)          | 0 bytes           | `{"mcpServers":{}}` (had `teams`) |
| `wiped-leftover` | `tag-skill/SKILL.md`, `tag/tagcmd.md`, `recipe-from-project/SKILL.md`               | 0 bytes           | `{"mcpServers":{}}` (had `teams`) |
| `tagproj`        | as `wiped-leftover`, plus a hand-written `CLAUDE.md`                                | 0 bytes           | `{"mcpServers":{}}` (had `teams`) |
| `normal`         | `tag-skill/SKILL.md`, `tag/tagcmd.md`                                               | 773 bytes         | `teams`               |
| `handwritten`    | `CLAUDE.md` only                                                                    | absent            | absent                |
| `empty`          | nothing                                                                             | absent            | absent                |

#### Before and after

The `# evidence-check` block was taken from the skill file as written, before (`git show HEAD:...` at 3729eee) and after (d070dee), and run in both shells:

```bash
awk '/^# evidence-check$/{f=1} f&&/^```$/{exit} f' <skill file> > "$T/check-<before|after>.sh"
for d in ruly-copy fully-wiped wiped-leftover tagproj normal handwritten empty; do
  b=$(PROJECT="$P/$d" bash "$T/check-X.sh"); z=$(PROJECT="$P/$d" zsh "$T/check-X.sh")
  printf '%-15s bash=%-18s zsh=%s\n' "$d" "$b" "$z"
done
```

Before (3729eee):

```text
ruly-copy       bash=evidence-ok        zsh=evidence-ok
fully-wiped     bash=no-evidence        zsh=no-evidence
wiped-leftover  bash=evidence-ok        zsh=evidence-ok
tagproj         bash=evidence-ok        zsh=evidence-ok
normal          bash=evidence-ok        zsh=evidence-ok
handwritten     bash=evidence-ok        zsh=evidence-ok
empty           bash=evidence-ok        zsh=evidence-ok
```

After (d070dee; `bash -n` and `zsh -n` both pass):

```text
ruly-copy       bash=clobbered-partial  zsh=clobbered-partial
fully-wiped     bash=no-evidence        zsh=no-evidence
wiped-leftover  bash=clobbered-partial  zsh=clobbered-partial
tagproj         bash=clobbered-partial  zsh=clobbered-partial
normal          bash=evidence-ok        zsh=evidence-ok
handwritten     bash=evidence-ok        zsh=evidence-ok
empty           bash=no-evidence        zsh=no-evidence
```

Extra edge cases, after the fix, in both shells:

```text
badjson   (only a .mcp.json holding "not json")              no-evidence
selfonly  (only .claude/skills/recipe-from-project/SKILL.md) no-evidence
cursor    (only .cursor/rules/style.mdc)                     evidence-ok
```

The four requested cases: this ruly repo after a wipe moves from `evidence-ok` to `clobbered-partial`, and the fully wiped project stays `no-evidence`. The normally squashed project and the hand-written-only project both stay `evidence-ok`. The empty project, WR-02's case, reports `no-evidence`. `prettier --check` passes on the skill file.

---

_Fixed: 2026-11-08T09:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 3_
