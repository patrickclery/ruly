---
phase: 07-competitor-composition-audit
verified: 2026-11-08T08:00:00Z
status: passed
score: 6/6 must-haves verified
covered_files:
  - ".planning/phases/07-competitor-composition-audit/07-01-PLAN.md"
  - ".planning/phases/07-competitor-composition-audit/07-01-SUMMARY.md"
  - ".planning/phases/07-competitor-composition-audit/07-AUDIT.md"
  - ".planning/research-competitive-2026-11-01.md"
  - "README.md"
covered_digest: "v3:sha256:cc09561eb11775e8d0bd1d1d5602f170eb2dd6c9edebda11038b08288640ae4b"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 6/6
  gaps_closed: []
  gaps_remaining: []
  regressions: []
advisory:
  - finding: "README comparison row 'Agents' says ruly has '3 targets: claude, agents and cursor', but `-a` now accepts a fourth value, `claude-plugin` (added by Phase 5 commit c0895d7, about two minutes after the Phase 7 README commit d26fb03)"
    category: other
    reason: "`claude-plugin` is a packaging format for Claude Code, not a fourth agent, so the 3-agent count is defensible and the error understates ruly rather than misstating a rival. `-a` help lists 4 values. Consider 'three agents' or a mention of the plugin form. Changing the README is outside this verification."
    evidence_status: "lib/ruly/cli.rb:40 lists 'claude, cursor, agents, claude-plugin'"
---

# Phase 7: Competitor Composition Audit Verification Report

**Phase Goal:** Verify whether Ruler's and rulesync's composition models (nesting, includes, profiles) offer task-scoped selection comparable to recipes + `requires:`; feed results into Phase 3 positioning.
**Verified:** 2026-11-08
**Status:** passed
**Re-verification:** Yes. The previous report went stale because README.md changed after it ran (Phases 5, 6 and 8). Every truth was re-checked against the current tree.

## What changed in README.md since the Phase 7 commit (d26fb03)

`git diff d26fb03 HEAD -- README.md` has 9 hunks. None is inside the `## Ruly vs. Ruler and rulesync` section (lines 114-147). The edits are:

- One line replaced in the native table, the Token cost row. Phase 6 added the benchmark figures.
- A new `-a claude-plugin` bullet (Phase 5).
- The `/recipe-from-project` bullet and its fetch note under "Available Ruly Commands" (Phase 8).
- Other Phase 5, 6 and 8 additions elsewhere.

The Phase 7 section is byte-identical to what the earlier report verified. The Why ruly bullets are unchanged.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 07-AUDIT.md answers the open question from primary sources (no profiles, includes or cycle detection in either rival) | VERIFIED | 07-AUDIT.md was not modified after the earlier report. I re-read the pinned sources with `gh api` (read-only). rulesync `config.ts` @6e3869d has 0 matches for `profile` or `preset`. Ruler `ConfigLoader.ts` and `RuleProcessor.ts` @5e551e6 were confirmed in the earlier report and the pins are immutable. |
| 2 | 8-row capability matrix with the stated verdicts and a SHA-pinned Evidence subsection per row | VERIFIED | Unchanged. 07-AUDIT.md still has the matrix and the Evidence subsections. Row 8 reads 32 / 69 / 3. |
| 3 | Method limitation recorded: no third-party code executed, vibe-rules out of scope, interop deferred | VERIFIED | `grep -c "No third-party code was executed"` on 07-AUDIT.md returns 1. A grep for `npx ruler`, `npx rulesync` and `npm install` in README.md and 07-AUDIT.md returns nothing. |
| 4 | README has `## Ruly vs. Ruler and rulesync` after the native table, exactly 7 rows, verdict-first rival cells, SHA-pinned reference links | VERIFIED | Section at README.md:114, after the native table at :92. It has 7 data rows. Rival cells open with No, Yes, Partial or the count. A grep for `intellectronica/ruler` or `dyoshikawa/rulesync` URLs not pinned to `5e551e6` or `6e3869d` returns nothing in README.md or 07-AUDIT.md. The Why ruly pointer sentence still links `(#ruly-vs-ruler-and-rulesync)`. |
| 5 | README concedes parity (per-subagent model Yes/Yes, rulesync shared sources plus lockfile Yes, post-compile checks Partial/Partial, agents 32 and 69 vs 3) | VERIFIED (see advisory) | The rows are intact. Per-subagent model is Yes/Yes. Shared source is No/Yes with `rulesync.lock`. Post-compile checks are Partial/Partial. Agents read 32, 69 and 3. A grep for uniqueness words (`only`, `sole`, `unique`, `best`, `first`, `alone`, `none of`) matches only two descriptive uses in ruly's own cells ("writes only that set" and "written only for Claude Code"). Neither claims uniqueness. The "3 targets" figure for ruly is now arguably stale because of `claude-plugin`; see the advisory in the frontmatter. It is not a rival-facing claim and the 3-agent count holds if the plugin form is treated as packaging. |
| 6 | Research doc answers the open question and option 4, has six `Phase 7 correction` notes, rulesync 69 targets, and a `## Phase 7 follow-up` section pointing to 07-AUDIT.md | VERIFIED | `grep -c "Phase 7 correction"` returns 6. Line 22 and line 59 carry "Answered 2026-11-02". `## Phase 7 follow-up (2026-11-02)` is at line 65 and cites 07-AUDIT.md. |

**Score:** 6/6 truths verified (0 behavior-unverified; the truths are documentary).

### Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No sole-tool or ranking claims; no ruly-only framing of parity items | PASS | See truth 5. |
| No unpinned or unverified evidence; inferred `generate -c` stays out of README | PASS | The pin grep is clean. `generate -c` is absent from the README section. |
| No running or installing Ruler or rulesync | PASS (documentary) | No npx or npm string in the deliverables. This re-verification also only used `gh api` raw reads. |
| Must not say ruly detects broken anchors or that squash fails on cycles | PASS | README says "ambiguous anchor links (a heading that appears more than once)". `lib/ruly/checks/ambiguous_links.rb` and `find_circular_dependencies` in `lib/ruly/operations/stats.rb:124` match. Cycles are "listed by `ruly stats`; squash includes each file once". |
| No rewrite of Why ruly bullets or the native table | PASS for Phase 7 | The Phase 7 commit did not touch them. Later edits to the native table (Phase 6 benchmark figures) belong to other phases. |
| No README link to `.planning/` | PASS | `grep -n .planning README.md` is empty. |
| No vibe-rules or interop coverage beyond a scope note | PASS | Unchanged. |
| No edits to lib, spec, site or rules in the Phase 7 task commits | PASS | Unchanged. Commits 7228a31, e6967f0 and d26fb03 are docs only. |

### Spot-Checks of README Competitor Claims Against Pinned Sources

Re-read through `gh api` raw contents at the pinned SHAs. No third-party code was executed.

| README claim | Source | Result |
|---|---|---|
| Ruler: 32 agent targets | `src/agents/index.ts` @5e551e6 L39-L70 | CONFIRMED. 32 `new ...Agent()` entries. |
| rulesync: config has no profile or preset key | `src/config/config.ts` @6e3869d | CONFIRMED. 0 matches. |
| rulesync: `generate --check` exits 1 on stale output | `src/cli/program.ts` @6e3869d L365 | CONFIRMED. The `--check` option text says it exits with code 1 if changes are needed. |
| Other Ruler and rulesync cells (subagent model, XDG fallback, lockfile, 69 targets) | pinned blobs | Pins are immutable and the earlier report confirmed them. The README cells are unchanged since. |

### Spot-Checks of README Ruly Claims Against Current Code

| README claim | Current code | Result |
|---|---|---|
| `ruly stats` lists circular `requires:` chains | `Operations::Stats#find_circular_dependencies` (`lib/ruly/operations/stats.rb:124`) | CONFIRMED |
| Model falls back subagent to recipe to `inherit` | `resolve_agent_model` (`lib/ruly/services/subagent_processor.rb:321`) | CONFIRMED |
| `ruly squash --sync` mirrors shared recipes | `option :sync` (`lib/ruly/cli.rb:54`) | CONFIRMED |
| Squash checks for ambiguous anchor links | `lib/ruly/checks/ambiguous_links.rb` | CONFIRMED |
| 3 targets: claude, agents, cursor | `lib/ruly/cli.rb:40` lists 4 `-a` values: claude, cursor, agents, claude-plugin | PARTIAL. Advisory only; see frontmatter. |

### Requirements Coverage

The phase declares no requirement IDs (`Requirements: TBD` in ROADMAP). Nothing is mapped to the phase, so there are no orphans.

### Anti-Patterns Found

None. There are no TBD, FIXME or XXX markers in the Phase 7 deliverables, and nothing is a stub. The deliverables are documentation.

### Human Verification Required

None. The earlier report recorded no human-verified items, and the README changes do not affect any.

### Gaps Summary

No gaps. The audit answers the phase question from pinned primary sources: neither Ruler nor rulesync has profiles, transitive includes or include-cycle detection. The README section is unchanged since it was verified, and its Ruler and rulesync claims still hold at the pinned SHAs. One non-blocking advisory: the Phase 5 `claude-plugin` value means "3 targets" for ruly now needs a word of qualification.

---

_Verified: 2026-11-08_
_Verifier: Claude (gsd-verifier)_
