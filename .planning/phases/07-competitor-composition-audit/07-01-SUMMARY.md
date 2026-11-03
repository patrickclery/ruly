---
phase: 07-competitor-composition-audit
plan: 01
subsystem: docs
tags: [competitive-analysis, readme, ruler, rulesync]
status: complete
requires: []
provides:
  - 07-AUDIT.md capability matrix (8 rows) with SHA-pinned evidence
  - README "Ruly vs. Ruler and rulesync" section (7 rows)
  - Answered open question in the 2026-11-01 research doc
affects: [README.md, .planning/research-competitive-2026-11-01.md]
tech-stack:
  added: []
  patterns: [SHA-pinned reference links for third-party claims]
key-files:
  created:
    - .planning/phases/07-competitor-composition-audit/07-AUDIT.md
  modified:
    - README.md
    - .planning/research-competitive-2026-11-01.md
decisions:
  - "Neither Ruler nor rulesync has profiles, includes or include-cycle detection; recipes plus requires: stay ruly's main difference"
  - "README concedes per-subagent model (both rivals), shared sources with lockfile (rulesync), partial checks (both) and agent counts 32/69 vs 3"
  - "vibe-rules out of scope; interop deferred; no third-party code executed"
metrics:
  duration: 6min
  completed: 2026-11-02
actuals:
  tokens: 10600
  tasks: 3
  commits: 4
plan_head_before: 65d088097b3883c8fc140a1af0a25c9256ade093
plan_head_after: d26fb037bceecb59bed9ba1c6594b2d54361febf
---

# Phase 7 Plan 01: Competitor Composition Audit Summary

Pinned, read-only audit of Ruler @5e551e6 and rulesync @6e3869d: neither has named rule sets, transitive includes or include-cycle detection; the README now has a 7-row comparison that concedes parity on per-subagent model, shared sources, checks and agent coverage.

## Tasks

| Task | Name                                                             | Commit  | Files                                |
| ---- | ---------------------------------------------------------------- | ------- | ------------------------------------ |
| 1    | Tracer: includes verdict end to end                              | 7228a31 | 07-AUDIT.md, README.md, research doc |
| 2    | Complete 07-AUDIT.md (8 rows, corrections, mapping, spot-checks) | e6967f0 | 07-AUDIT.md                          |
| 3    | README rows, Why ruly link, research corrections                 | d26fb03 | README.md, research doc              |

`commits: 4` is the measured `rev-list` count from the plan ledger; it includes `29ec71d docs(06): create phase plan`, committed concurrently by the Phase 6 planner. Three commits belong to 07-01.

## Verification

- Task 1, 2, 3 gates (including the research-doc gate) print only `END` in bash and zsh.
- `npx --no-install prettier --check` passes on all three files.
- Commit scope: 3 `(07-01)` commits, none touching anything outside README.md and `.planning/`.
- Executor spot-checks (read-only `gh api`, copies kept in the session scratchpad): Ruler `FileSystemUtils.ts` L199-L237, rulesync `tool-targets.ts` L23-L31, Ruler `SubagentsProcessor.ts` L403-L416 and L176. All matched the plan; no verdict changed.

## Deviations from Plan

**1. [Orchestrator note] Agents-row cells start with the plain count**

- **Found during:** Task 3
- **Issue:** the plan's recommended Agents cells began with a backtick (`` `32` ``), but the Task 3 gate requires the cell to start with `32`/`69`.
- **Fix:** wrote "32 agent targets, …" and "69 `--targets` values, …" without the leading backticks. Facts and verdicts unchanged.
- **Commit:** d26fb03

**2. [Wording] Cycle reporting rulesync cell spelled out**

- The plan suggested "No. same reason"; the cell repeats the full reason so it reads on its own. Verdict and link unchanged.

## Auto-decisions

- Tracer gate: auto-verified (all `<verify>` gates re-run and passed) before expanding.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: .planning/phases/07-competitor-composition-audit/07-AUDIT.md
- FOUND: 7228a31, e6967f0, d26fb03 (ancestors of HEAD)
