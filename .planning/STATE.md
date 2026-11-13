---
gsd_state_version: "1.0"
current_phase: 03
status: completed
stopped_at: Phase 03 complete — all phases complete
last_updated: "2026-11-13T09:19:56.395Z"
last_activity: 2026-11-13
last_activity_desc: Phase 03 complete
state_head: eb5b3318f2fc2b6a6aad41e4017b41d5002c82c7
progress:
  total_phases: 8
  completed_phases: 8
  total_plans: 16
  completed_plans: 16
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-02)

**Core value:** Rules get squashed correctly into agent instruction files every time
**Current focus:** Phase 03 — Emphasize Core Advantages

## Current Position

Phase: 03
Plan: Not started
Status: All phases complete
Last activity: 2026-11-13 — Phase 03 complete

Progress: [██████████] 100% (existing work)

## Performance Metrics

**Velocity:**
- Total plans completed: 16 (brownfield -- no tracked plans yet)
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Core Platform | N/A | N/A | N/A |
| 02 | 3 | - | - |
| 04 | 2 | - | - |
| 07 | 1 | - | - |
| 03 | 1 | - | - |
| 05 | 3 | - | - |
| 06 | 3 | - | - |
| 08 | 3 | - | - |

**Recent Trend:**
- Last 5 plans: N/A
- Trend: N/A

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 02 P01 | 3 min | 3 tasks | 8 files |
| Phase 02 P02 | 6 min | 3 tasks | 13 files |
| Phase 02 P03 | 2 min | 2 tasks | 6 files |
| Phase 03 P01 | 3min | 3 tasks | 4 files |
| Phase 04 P01 | 5min | 3 tasks | 12 files |
| Phase 04 P02 | 6min | 2 tasks | 4 files |
| Phase 07 P01 | 6min | 3 tasks | 3 files |
| Phase 05 P01 | 8 min | 2 tasks | 16 files |
| Phase 05 P02 | 10 min | 2 tasks | 8 files |
| Phase 05 P03 | 4 min | 2 tasks | 3 files |
| Phase 06 P01 | 10min | 3 tasks | 47 files |
| Phase 06 P02 | 10min | 2 tasks | 15 files |
| Phase 06 P03 | 3min | 2 tasks | 3 files |
| Phase 08 P01 | Tasks 2-3 ~30min (continuation) | 3 tasks | 1 files |
| Phase 08 P02 | 15min | 3 tasks | 2 files |
| Phase 08 P03 | 4min | 3 tasks | 1 files |

## Accumulated Context

### Roadmap Evolution

- Phase 2 added: Lean Out Native Duplication (from 2026-11-01 competitive research)
- Phase 3 added: Emphasize Core Advantages (from 2026-11-01 competitive research)
- Phase 4 added: AGENTS.md Output Target (from 2026-11-01 competitive research)
- Phase 5 added: Claude Code Plugin Packaging (from 2026-11-01 competitive research)
- Phase 6 added: Token and Compliance Benchmark (from 2026-11-01 competitive research)
- Phase 7 added: Competitor Composition Audit (from 2026-11-01 competitive research)
- Phase 8 added: Project-to-recipe generator skill

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: Brownfield project -- all v1 requirements pre-existing and complete
- [Phase 02]: Thor check_unknown_options! is class-wide: removed or undeclared switches on any command exit 1 with Unknown switches (D-09)
- [Phase 02]: D-13: shell_gpt/sgpt dropped (now plain markdown), cursor kept until AGENTS.md in Phase 4
- [Phase 02]: D-03 fold: stats gains Analyzer's console summary; context-window percentages (--tier, tier:, contexts.yml) dropped
- [Phase 02]: Recipe key warnings: once per recipe per run on stderr, key names only, never values; squash continues
- [Phase 02]: AUDIT.md marks the mcp command/flags as delegate (claude mcp add, Phase 5 plugin .mcp.json); other removals as remove
- [Phase 03]: Ruly vs. native table concedes native subagent model:/skills:; ruly's edge is generating them per recipe with fallback
- [Phase 03]: Token-cost row states no percentage until the Phase 6 benchmark
- [Phase 03]: Subagents subtree moved verbatim under ## Reference with a pointer at its old spot
- [Phase 04]: AGENTS.md target routes around post_squash; logic lives in Services::AgentsMd
- [Phase 04]: Fixture rules/ files force-added because .gitignore rules/ matches any rules dir
- [Phase 04]: ruly.gemspec reads Ruly::VERSION; 0.3.0 gem install deferred to post-merge
- [Phase 07]: Phase 7 audit: neither Ruler nor rulesync has profiles, includes or include-cycle detection; README concedes per-subagent model, shared sources, partial checks and agent counts
- [Phase 05]: 05-01: claude-plugin ownership marker is plugin.json metadata.generator=ruly; reset_dir writes it first so failed runs stay re-runnable
- [Phase 05]: 05-01: rules ship as skill RECIPE-rules plus always-on notice (D-09); no CLAUDE.md/SessionStart/output style in plugins
- [Phase 05]: Plugin agent skills: are a YAML list of namespaced PLUGIN:skill names (assumption A3, post-run human check)
- [Phase 05]: Nested skill names are flattened for the plugin only; claude target keeps nested layout
- [Phase 05]: 0.4.0 released for the claude-plugin target; README documents that plugin rules are a skill, not always-on
- [Phase 06]: Fixture token benchmark: median ruly reduction 76.9% vs load-all, 68.4% vs native floor, 74.3% vs native ceiling (synthetic corpus, 5 recipes)
- [Phase 06]: bench/ harness runs real bin/ruly squash with isolated HOME/RULY_HOME; non-fixture corpora write only to git-ignored bench/results/local
- [Phase 06]: Compliance harness: dry run default; --live runs claude -p (claude-sonnet-5-5) with per-call budget cap; OutputDir guard shared with TokensCLI
- [Phase 06]: Benchmark docs publish the fixture median (76.9% vs load-all, 68.4% vs native floor), always labeled fixture-based; compliance marked pending a paid live run
- [Phase 08]: recipe-from-project: match order stays name first, then content, per CONTEXT
- [Phase 08]: recipe-from-project: no-match report includes the name collision check; drafts list entries in full
- [Phase 08]: 08-02: rules repo sort commit restores yalphabetize's comment reindents and whitespace so it reorders lines only
- [Phase 08]: 08-03: separate-pr with merge and rules-push yes, chosen by the orchestrator under the user's standing bypass instruction; PR #5 merged (0d91b71), rules main pushed after gates
- [Phase 03]: 2026-11-13 re-verification after the site update: 3 review warnings fixed in site/app/page.tsx; the quick-task cards accepted as a D-10 override by the orchestrator on the user's standing instruction (reversible, see 03-VERIFICATION.md); 4 Info findings left open in 03-REVIEW.md

### Pending Todos

None yet.

### Blockers/Concerns

- ⚠️ [Phase 2] `.planning/codebase/*` maps are stale (still describe Analyzer, cache, shell_gpt) — run /gsd-map-codebase
- ⚠️ [Phase 2] patrickclery/rules `core-debugger` recipe uses misspelled `omitCommandPrefix` (now warns); top-level `tier:` in ~/.config/ruly/recipes.yml is inert (now warns)
- ⚠️ [Phase 2] Installed `ruly` binary not refreshed with 0.2.0 changes (per CLAUDE.md: update after changes)
- ⚠️ [Phase 2] Pre-existing: 15 baseline rspec failures; `ruly stats` writes stats.md into gem rules/ dir regardless of cwd

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 261108-fxc | Update demo site for phases 4-8 and merge to main | 2026-11-08 | 31ceba0 | [261108-fxc-update-demo-site-for-phases-4-8-and-merg](./quick/261108-fxc-update-demo-site-for-phases-4-8-and-merg/) |

## Deferred Verification

| Phase | State | Resume |
|-------|-------|--------|

## Session Continuity

Last session: 2026-11-13T09:40:00Z
Stopped at: Phase 03 complete — all phases complete
Resume file: None
