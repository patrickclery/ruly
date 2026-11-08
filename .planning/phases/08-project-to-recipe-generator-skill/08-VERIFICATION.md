---
phase: 08-project-to-recipe-generator-skill
verified: 2026-11-08T08:10:00Z
status: passed
score: 10/10 must-haves verified
covered_files:
  - ".planning/phases/08-project-to-recipe-generator-skill/08-01-PLAN.md"
  - ".planning/phases/08-project-to-recipe-generator-skill/08-01-SUMMARY.md"
  - ".planning/phases/08-project-to-recipe-generator-skill/08-02-PLAN.md"
  - ".planning/phases/08-project-to-recipe-generator-skill/08-02-SUMMARY.md"
  - ".planning/phases/08-project-to-recipe-generator-skill/08-03-PLAN.md"
  - ".planning/phases/08-project-to-recipe-generator-skill/08-03-SUMMARY.md"
  - "README.md"
  - "skills/recipe-from-project.md"
covered_digest: "v3:sha256:4bc45035e87a1c10e58a84d642b8fb2d926246ac9480e733a5eca27cda8e55dd"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 8: Project-to-recipe generator skill Verification Report

**Phase Goal:** A Ruly skill takes a project folder and drafts a recipe from the rules, skills and other agent configuration that project currently uses. Built as an AI skill rather than a CLI command because matching a project's setup to shared rules takes judgment; `ruly introspect` only lists markdown files.
**Verified:** 2026-11-08
**Status:** passed
**Re-verification:** No (initial verification; the code-review fix rounds are covered below)

ROADMAP has no success criteria and no requirement IDs are mapped, so the truths come from the three PLAN `must_haves` blocks, merged and de-duplicated.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The skill exists as an AI skill, not Ruby: two-key frontmatter, no `lib/` change | VERIFIED | `skills/recipe-from-project.md` (431 lines) has only `name` and `description`. `git diff --name-only 113daf6 HEAD` outside `.planning` is `README.md` and the skill file only. `git log 113daf6..HEAD -- lib` is empty. |
| 2 | Squashing a recipe that lists the skill writes `.claude/skills/recipe-from-project/SKILL.md` with a body equal to the source | VERIFIED | Re-run under a temp HOME: `ruly squash ruly-tools` exit 0, `SKILL.md` written, frontmatter `name`/`description` only, stripped body equals the source (`true`). |
| 3 | Takes a project path from `$ARGUMENTS`, defaults to cwd, scans CLAUDE.md, CLAUDE.local.md, AGENTS.md, .cursor/rules, .claude/skills/commands/agents and .mcp.json, ignores `.ruly.yml` | VERIFIED | Steps 1-2 and the scan table in the skill. Headless checks A and C (08-01 SUMMARY) show the path arriving through `$ARGUMENTS` and a no-argument stop. |
| 4 | Matching runs name, then content, then judgment, and every draft entry is labelled exact or inferred | VERIFIED | `exact-match` and `url-match` blocks plus the Step 3 signals table. The `exact-match` block on homelab gave 26/26 exact skills (08-01 gates). Check D (core-solo) labelled URL entries `exact-url`. |
| 5 | A folder left by squashing `ruly-tools` is detected and the skill does not draft from it silently | VERIFIED | `evidence-check` re-run here: Route 2 output folder gives `no-evidence`. A hand-built clobbered folder with a hand-written `CLAUDE.md` gives `clobbered-partial`. A hand-written-only folder gives `evidence-ok`. This repo gives `evidence-ok`. The orchestrator's headless run on a wiped fixture printed `clobbered-partial`, listed `CLAUDE.md` and the three commands, asked before drafting, and left the rules copy's `git status` empty. This closes the review's CR-01 iteration 3 item. |
| 6 | Unmatched content is reported, not turned into a recipe entry or a rule file. When nothing matches the skill writes nothing | VERIFIED | Step 5 and Step 6. Headless check B on this repo: no match, three commands and `CLAUDE.md` reported, name `ruly` flagged as taken, copy status empty (08-01 and 08-03 SUMMARY). |
| 7 | The draft is shown first, and only after approval is it inserted at its sorted position, preflighted, dry-run under a temp HOME, and left uncommitted | VERIFIED | Steps 6-9 and the `preflight` and `validate-recipe` blocks. Check E: only ` M recipes.yml`, HEAD unchanged. Check F: bad path reported as `missing-path` and `File not found` despite exit 0. Decline check: nothing written. |
| 8 | The skill is published on `main` and the `ruly-tools` URL resolves and validates after PR #6 | VERIFIED | `gh api ...contents/skills/recipe-from-project.md?ref=main` exit 0 and `cmp` against the local file exit 0. Plan gate-1 `validate-recipe` block, taken from the main copy and run with `RULES=~/github.com/patrickclery/rules RECIPE=ruly-tools` under a temp HOME: `exit=0`, `.claude/skills/recipe-from-project/SKILL.md` listed, empty findings, rules clone `git status` empty. The `ruly-tools` entry is also on remote rules `main`. |
| 9 | README lists the skill first, gives both routes, warns against squashing `ruly-tools` in the scanned project, notes the network need | VERIFIED | `README.md` lines 893-920: first bullet under Available Ruly Commands, section "Drafting a Recipe From a Project" with both routes, the warning, and the offline-exit-1 note. Prettier check on the skill passes. |
| 10 | Rules repo order and safety: sort commit separate from the `ruly-tools` commit, pushed only after the file reached `main`, and `~/.config/ruly/recipes.yml` untouched | VERIFIED | Rules `log`: 611a89e (recipe) on 51e5fe8 (sort), local equals `origin/main`, clean status. `ruly-tools` is a 4-line entry at `recipes.yml:1111`. `~/.config/ruly/recipes.yml` mtime is 2026-10-05, and the real HOME was not used in any check above. 08-03 recorded `pushed-in-order`. |

**Score:** 10/10 truths verified (0 present, behavior-unverified)

### Prohibitions

| Prohibition | Result | Evidence |
|-------------|--------|----------|
| No `requires:`, `dispatches:` or other frontmatter keys in the skill | Held | Frontmatter is `name` and `description` only. |
| No private rule text, tokens, rule source paths or slash command names in the public skill | Held | Every skill line of 50+ characters was searched for in the rules clone: 0 hits. A token-pattern grep found none in the skill, and the one README match is the word "xox" inside prose, a false positive. |
| No non-dry squash, `--sync`, `--deepclean`, `--cache` or commit by the skill | Held | Only squash call in the skill is `--dry-run` under a temp HOME. Step 9 states the limits. |
| No Ruby helper and no `lib/` change | Held | See truth 1. |
| Nothing staged except the allowed files | Held | Phase commits touch only the skill, README, and `.planning`. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/recipe-from-project.md` | Self-contained skill with `# exact-match` and the other fenced blocks | VERIFIED | Substantive (431 lines, blocks `evidence-check`, `exact-match`, `url-match`, `preflight`, `validate-recipe`). Wired: on `main`, byte-identical, fetched by a squash, SKILL.md generated. |
| `README.md` | Skill bullet and `#### Drafting a Recipe From a Project` | VERIFIED | Present and contains the routes. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Rules `ruly-tools` skills entry | `skills/recipe-from-project.md` on `main` | squash-time GitHub fetch | WIRED | Squash under temp HOME fetched it and wrote the SKILL.md. |
| `validate-recipe` block | RecipeLoader mirror lookup | temp HOME with clone as `remotes/patrickclery/rules` | WIRED | Dry run saw the clone's `ruly-tools` recipe. |
| `exact-match` block | `FrontmatterParser.strip_metadata` split rule | same `split(/^---\s*$/, 3)` | WIRED | Generated body equals the source (truth 2). |
| README routes | skill Examples section | same two routes and URL | WIRED | Both name the URL and `ruly squash ruly-tools`. |

### Data-Flow Trace (Level 4)

Not applicable. The deliverable is an instruction document with shell and Ruby blocks, with no rendered dynamic data. The blocks read the live project and clone each run and index the clone fresh.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| URL on `main` equals local file | `gh api ... ?ref=main` then `cmp` | `fetch=0 cmp=0` | PASS |
| `ruly-tools` validates | `validate-recipe` block, temp HOME | `exit=0`, no findings | PASS |
| URL skill squashes to correct SKILL.md | `ruly squash ruly-tools`, temp HOME and cwd | exit 0, body equal | PASS |
| Evidence check classes | `evidence-check` on four hand-built folders and this repo | `no-evidence`, `clobbered-partial`, `evidence-ok`, `no-evidence` (nonexistent), `evidence-ok` | PASS |
| Warn-and-ask on wiped fixture | Orchestrator's headless `claude -p` run (scratchpad `warnask/out.txt`) | `clobbered-partial`, listed what was left, asked, wrote nothing | PASS |

The user waived interactive checkpoints. The session behaviors (approval gate, decline, no-match, no-argument, pruning, URL entries, approved write, bad path) were recorded as headless `claude -p` runs in the 08-01 and 08-03 SUMMARYs, each with its observed result and a clean rules `git status`. I judged them on that record and found nothing that only a person could show.

### Probe Execution

SKIPPED. No `probe-*.sh` scripts are declared or present for this phase.

### Requirements Coverage

No requirement IDs are mapped to Phase 8 (ROADMAP `Requirements: TBD`), and `REQUIREMENTS.md` has no Phase 8 rows. Nothing is orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `skills/recipe-from-project.md` | none | `TBD`, `FIXME` or `XXX` markers | none | Clean. |

Open review items are IN-01 to IN-08 (08-REVIEW.md, iteration 3, outside the fix scope). They are info-level edge cases: the name check crashing when `recipes.yml` has no `recipes:` key, YAML-reserved names, silent URL fetch failures, no stated "nonzero exit is a failure" rule, an undocumented 200-character cutoff, a README note, a sort-order note, and a dry-run line-mapping note. None breaks the goal or a must-have. They are advisory and do not affect the status.

### Human Verification Required

None. The user waived interactive checks, and each was run headless with recorded evidence.

### Gaps Summary

No gaps. The skill exists on public `main` and is byte-identical to the local file. The `ruly-tools` recipe is on rules `main`, and it fetches and validates under a temp HOME after PR #6. A draft is shown before any write, an approved insert is left uncommitted, and the iteration 3 clobber-detection fix behaves as intended. Deferred Ruby follow-ups (dry-run exit codes, `--strict`, unknown MCP names, block-scalar descriptions, installed `ruly` 0.1.0 against 0.4.0) are recorded in the 08-03 SUMMARY as out of scope for this phase.

---

_Verified: 2026-11-08T08:10:00Z_
_Verifier: Claude (gsd-verifier)_
