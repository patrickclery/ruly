---
phase: 07-competitor-composition-audit
verified: 2026-11-02T05:00:00Z
status: passed
score: 6/6 must-haves verified
covered_files:
  - ".planning/phases/07-competitor-composition-audit/07-01-PLAN.md"
  - ".planning/phases/07-competitor-composition-audit/07-01-SUMMARY.md"
  - ".planning/phases/07-competitor-composition-audit/07-AUDIT.md"
  - ".planning/research-competitive-2026-11-01.md"
  - "README.md"
covered_digest: "v3:sha256:2d5bbdb0a1ece263d10976a889e70e8e492c92c5d0295a648d3c26547c57bd30"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 7: Competitor Composition Audit Verification Report

**Phase Goal:** Verify whether Ruler's and rulesync's composition models (nesting, includes, profiles) offer task-scoped selection comparable to recipes + `requires:`; feed results into Phase 3 positioning.
**Verified:** 2026-11-02
**Status:** passed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 07-AUDIT.md answers the open question from primary sources (no profiles, includes, or cycle detection in either rival) | VERIFIED | The Answer section is in 07-AUDIT.md. I re-read Ruler `ConfigLoader.ts` @5e551e6: the schema is `.strict()` with keys `default_agents`, `agents`, `mcp`, `skills`, `subagents`, `nested`, and no profile key. `grep -i profile\|preset` on Ruler `ConfigLoader.ts` and rulesync `config.ts` @6e3869d returns nothing. Ruler `RuleProcessor.ts` `concatenateRules` only joins files with `<!-- Source -->` markers. rulesync `rulesync-rule.ts` frontmatter has `root`, `localRoot`, `targets`, `description`, `globs` and per-tool blocks, with no `requires` or include key. |
| 2 | 8-row capability matrix with the stated verdicts and a SHA-pinned Evidence subsection per row | VERIFIED | The matrix has 8 rows and verdicts match the plan (Ruler no/no/no/no/yes/no/partial; rulesync no/partial/no/no/yes/yes/partial; ruly yes in every row; agents 32/69/3). Evidence subsections 1-8 each carry pinned `blob/<SHA>` links per rival. |
| 3 | Method limitation recorded: no third-party code executed; vibe-rules out of scope; interop deferred | VERIFIED | The Method section says "No third-party code was executed" and the Scope bullet covers vibe-rules and interop. No `npx ruler`/`npx rulesync`/`npm install` string appears in 07-AUDIT.md or README.md. |
| 4 | README has `## Ruly vs. Ruler and rulesync` after the native table, exactly 7 rows, verdict-first rival cells, SHA-pinned reference links | VERIFIED | Section at README.md:114, after the native table (line ~89). 7 data rows. Rival cells open with No/Yes/Partial or the count. All 14 rival reference definitions use `blob/` or `tree/` with the two recorded SHAs. A grep for unpinned `intellectronica/ruler` or `dyoshikawa/rulesync` URLs in README.md and 07-AUDIT.md returns none. |
| 5 | README concedes parity (Yes/Yes per-subagent model, rulesync Yes shared sources + lockfile, Partial/Partial checks, 32/69 vs 3 agents) | VERIFIED | README rows: Per-subagent model "Yes."/"Yes."; Shared source "No."/"Yes. ... `rulesync.lock`"; Post-compile checks "Partial."/"Partial."; Agents "32 agent targets"/"69 `--targets` values"/"3 targets". No uniqueness wording (grep for only/sole/unique/best/none of/first/alone in the section returns nothing). |
| 6 | Research doc answers the open question and option 4, has six `Phase 7 correction` notes, rulesync 69 targets, and a `## Phase 7 follow-up` section pointing to 07-AUDIT.md | VERIFIED | `grep -c "Phase 7 correction"` returns 6. Option 4 carries "Answered 2026-11-02 ... 07-AUDIT.md". The table row shows 69 `--targets` (61 with rules). `## Phase 7 follow-up (2026-11-02)` is at line 65. |

**Score:** 6/6 truths verified (0 behavior-unverified; the truths are documentary claims, not runtime state transitions)

### Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No sole-tool/ranking claims; no ruly-only framing of parity items | PASS | Grep above is clean. Parity rows are conceded in the table. |
| No unpinned or unverified evidence; inferred `generate -c` stays out of README | PASS | No unpinned rival URLs. `generate -c` appears only in 07-AUDIT.md, marked inferred/[ASSUMED]. |
| No running/installing Ruler or rulesync | PASS (documentary) | No npx/npm string in deliverables. Commits touch docs only. I cannot prove the negative about the executor's shell history; the AUDIT's own spot-check log shows `gh api` reads only. |
| Must not say ruly detects broken anchors or that squash fails on cycles | PASS | README says "ambiguous anchor links (a heading that appears more than once)"; cycles are "listed by `ruly stats`; squash includes each file once". |
| No rewrite of Why ruly bullets or the native table | PASS | `git diff 65d0880..HEAD -- README.md` removes exactly one line, the pointer sentence, which was extended with the new anchor link. All other changes are additions. |
| No README link to `.planning/` | PASS | `grep -n .planning README.md` is empty. |
| No vibe-rules or interop coverage beyond a scope note | PASS | README section has none. AUDIT has one scope bullet plus one interop note. |
| No edits to lib/spec/site/rules/CHANGELOG etc. in task commits | PASS | `git show --stat` for 7228a31, e6967f0 and d26fb03 touches only README.md, 07-AUDIT.md and the research doc. |

### Spot-Checks of README Competitor Claims Against Pinned Sources

Read via `gh api` raw contents at the pinned SHAs. No third-party code was executed.

| README claim | Source read | Result |
|---|---|---|
| Ruler: `ruler.toml` has no key that selects rule files | `ConfigLoader.ts` @5e551e6 L75-L129 | CONFIRMED. `.strict()` schema with no profile or rule-selection key. |
| Ruler: rule files joined with source markers; no include syntax | `RuleProcessor.ts` @5e551e6 L7-L28 | CONFIRMED. `concatenateRules` emits `<!-- Source: ... -->`; `@import` grep returns nothing in the files read. |
| Ruler: subagent takes a `model` field | `SubagentsUtils.ts` @5e551e6 L81-L86 | CONFIRMED. Optional string `model`. |
| Ruler: 32 agent targets including AGENTS.md | `src/agents/index.ts` @5e551e6 L39-L70 | CONFIRMED. 32 `new ...Agent()` entries, including `AgentsMdAgent`. |
| Ruler: XDG fallback as a whole, no remote | `FileSystemUtils.ts` @5e551e6 | CONFIRMED. `getXdgConfigDir()/ruler` fallback present; no merge or fetch in the lines read. |
| rulesync: config has no profile/preset key | `src/config/config.ts` @6e3869d | CONFIRMED. No match for profile or preset. |
| rulesync: rule frontmatter has no `requires`/include | `rulesync-rule.ts` @6e3869d | CONFIRMED. Keys are root, localRoot, targets, description, globs and per-tool blocks. |
| rulesync: `--input-roots`, `generate --check`, `-c` | `src/cli/program.ts` @6e3869d L342, L357, L365 | CONFIRMED. |
| rulesync: subagent per-tool model (`claudecode.model`) | `docs/reference/file-formats.md` @6e3869d | CONFIRMED. The subagent section has `claudecode: model: inherit`. |
| rulesync: sources pinned to SHAs in `rulesync.lock` | `docs/guide/declarative-sources.md` @6e3869d | CONFIRMED. Line 133 describes the SHA lockfile. |
| rulesync: 69 `--targets`, 61 with project rules, `agentsmd` present | `docs/reference/supported-tools.md` @6e3869d | CONFIRMED. I counted 69 target rows; 61 have a rules cell with the project mark, 1 is global-only, 7 are blank (packaging targets). |
| Ruly: 3 targets, models fall back subagent to recipe to `inherit`, `ruly stats` cycle DFS, `--strict`, `--sync` | `git show 4e85991:lib/ruly/...` | CONFIRMED. `-a` help lists claude, cursor, agents; `resolve_agent_model` and `find_circular_dependencies` match; `--strict` and `--sync` options exist. |

### Requirements Coverage

Phase declares no requirement IDs. None are mapped to the phase, so there are no orphans.

### Anti-Patterns

No debt markers (TBD/FIXME/XXX) in the modified docs. No stubs. The deliverables are documentation only.

### Notes (non-blocking)

- The `npx` run was intentionally dropped (D-02 override). The limitation is stated in 07-AUDIT.md and in the README footnote ("neither tool was run"). This is not a gap.
- Agent counts and line anchors are valid only for the pinned SHAs. README says so ("Agent counts change often").
- Rival "no" verdicts for rulesync mean "no such field exists in the schema or processor", not "rejected". 07-AUDIT.md states this.

### Human Verification Required

None.

### Gaps Summary

No gaps. The audit answers the phase question from pinned primary sources. Neither rival has profiles, transitive includes, or include-cycle detection. The README publishes only the verified parts and concedes parity where it exists. The research doc is corrected and cross-linked.

---

_Verified: 2026-11-02_
_Verifier: Claude (gsd-verifier)_
