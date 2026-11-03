# Phase 7: Competitor Composition Audit - Context

**Gathered:** 2026-11-02
**Status:** Ready for planning
**Note:** User was away (asked for unattended work). All decisions below are the recommended defaults, auto-accepted by Claude; revisit on review.

<domain>
## Phase Boundary

Verify, from primary sources (current READMEs, docs, and source code at a pinned commit), whether Ruler (intellectronica/ruler) and rulesync (dyoshikawa/rulesync) support task-scoped rule selection comparable to ruly recipes + `requires:` — nesting, includes, profiles/targets, dependency resolution, per-subagent model. Feed findings back into README/site positioning from Phase 3. Research + docs phase; no ruly code changes.

</domain>

<decisions>
## Implementation Decisions

### Method
- Read each project's docs AND source at a recorded commit SHA (cite SHA + file paths); docs claims alone are insufficient
- Where feasible, run each tool via `npx` in a scratch dir against a small fixture to confirm behavior (no global installs)
- Capability matrix rows: named rule sets/profiles, per-task selection, include/require with transitive resolution, cycle detection, per-subagent model selection, cross-machine shared source + per-machine overrides, post-compile checks, agent coverage

### Deliverables
- `.planning/phases/07-competitor-composition-audit/07-AUDIT.md` with the matrix, evidence links, and verdict per row (yes / partial / no / unverified)
- Update README "Ruly vs." section: add competitor comparison ONLY for rows with verified evidence; keep wording factual
- Update `.planning/research-competitive-2026-11-01.md` open question with the answer (or a follow-up note)

### Claude's Discretion
- Whether to also cover vibe-rules (only if time allows; mark as out of scope otherwise)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.planning/research-competitive-2026-11-01.md` — landscape, sources, open question
- README positioning from Phase 3

### Integration Points
- README.md comparison section; site copy if Phase 3 added competitor-related lines

</code_context>

<specifics>
## Specific Ideas

- "Whether rulesync or Ruler can select rules per task the way ruly's recipes and `requires:` do was not verified. That is the most important open question." — research doc

</specifics>

<deferred>
## Deferred Ideas

- Interop (handing AGENTS.md to Ruler/rulesync for fan-out) — future milestone

</deferred>
