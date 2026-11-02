# Roadmap: Ruly

## Overview

Ruly is a mature Ruby gem and CLI tool with all foundational capabilities already shipped. The squash pipeline, recipe system, multi-agent output, GitHub integration, and CLI commands are complete and in production use. This roadmap captures the existing state and serves as the anchor for future feature phases added via `/gsd:add-phase`.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Platform** - Squash pipeline, recipe system, multi-agent output, GitHub integration, and CLI (existing/complete)
- [x] **Phase 2: Lean Out Native Duplication** - Remove/delegate features Claude Code now does natively (completed 2026-11-02)
- [ ] **Phase 3: Emphasize Core Advantages** - Reposition around recipes, requires, sync, per-subagent models
- [x] **Phase 4: AGENTS.md Output Target** - Cross-agent reach via the standard (completed 2026-11-02)
- [ ] **Phase 5: Claude Code Plugin Packaging** - Ship output in native plugin format
- [ ] **Phase 6: Token and Compliance Benchmark** - Verify the 85% claim and compliance
- [x] **Phase 7: Competitor Composition Audit** - Check Ruler/rulesync task-scoped composition (completed 2026-11-02)

## Phase Details

### Phase 1: Core Platform

**Goal**: Users can compile modular markdown rules into agent-specific instruction files reliably
**Depends on**: Nothing (first phase)
**Requirements**: SQSH-01, SQSH-02, SQSH-03, SQSH-04, SQSH-05, SQSH-06, RCPE-01, RCPE-02, RCPE-03, RCPE-04, AGNT-01, AGNT-02, AGNT-03, GHUB-01, GHUB-02, CLI-01, CLI-02, CLI-03, CLI-04, CLI-05, CLI-06
**Success Criteria** (what must be TRUE):
  1. User can run `ruly squash` on a recipe and get a correctly merged markdown output with all dependencies resolved
  2. User can define and override recipes in YAML, with inheritance and introspection working
  3. User can generate output for Claude, Cursor, and Shell-GPT formats from the same rule sources
  4. User can fetch remote rule files from GitHub repositories without manual downloads
  5. User can run `ruly stats`, `ruly clean`, `ruly import`, `ruly init`, and `ruly analyze` for full CLI workflow

**Plans**: N/A (existing/complete)

## Progress

**Execution Order:**
Phases execute in numeric order.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Platform | N/A | Complete | Pre-existing |
| 2. Lean Out Native Duplication | 3/3 | Complete    | 2026-11-02 |
| 3. Emphasize Core Advantages | 1/1 | In Progress | - |
| 4. AGENTS.md Output Target | 2/2 | Complete    | 2026-11-02 |
| 5. Claude Code Plugin Packaging | 3/3 | In Progress | - |
| 6. Token and Compliance Benchmark | 2/3 | In Progress | - |
| 7. Competitor Composition Audit | 1/1 | Complete    | 2026-11-02 |

### Phase 2: Lean Out Native Duplication

**Goal:** Strip ruly down to its unique strengths by removing or delegating features that Claude Code now provides natively (plugins/skills package skills, commands, agents, hooks, MCP). Audit each CLI command and output type, keep recipes + `requires:` + per-subagent model + sync/overrides + post-squash checks, and deprecate the rest.
**Requirements**: TBD
**Depends on:** Phase 1
**Plans:** 3/3 plans complete

Plans:
**Wave 1**
- [x] 02-01-PLAN.md — Remove `--cache`, TaskMaster flags and shell_gpt output; removed switches fail loudly (tracer)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 02-02-PLAN.md — Remove `import`/`mcp`, fold `analyze` into `stats`, warn-and-continue on removed/unknown recipe keys

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 02-03-PLAN.md — AUDIT.md, 0.2.0 version + CHANGELOG, retire v1 requirements, README/docs cleanup

### Phase 3: Emphasize Core Advantages

**Goal:** Make ruly's verified advantages the headline: task-scoped recipe composition, `requires:` dependency resolution with cycle detection, per-subagent recipe/model selection, multi-machine `--sync` with per-machine overrides, and post-squash checks. Rewrite README/site positioning against native `.claude/rules/` (path-only scoping), `@imports` (no token savings), and symlink sharing limits.
**Requirements**: TBD
**Depends on:** Phase 2
**Plans:** 1/1 plans executed

Plans:
**Wave 1**
- [x] 03-01-PLAN.md — Why ruly + cited Ruly vs. native Claude Code table in README, site hero/cards copy (tracer), soften 85%, move Subagents reference below the fold, fix 0.2.0 command examples

### Phase 4: AGENTS.md Output Target

**Goal:** Emit AGENTS.md from a recipe so ruly reaches the ~30-60 agents Ruler/rulesync cover without per-agent adapters, keeping recipe composition as ruly's layer.
**Requirements**: TBD
**Depends on:** Phase 3
**Plans:** 2/2 plans complete

Plans:
**Wave 1**
- [x] 04-01-PLAN.md — `-a agents` writes AGENTS.md (tracer), skills inlined + skipped-parts notice + checks, marker-gated clean/overwrite guard, git-ignore

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 04-02-PLAN.md — README AGENTS.md Output section, 0.3.0 version/gemspec/CHANGELOG, installed binary refresh, closing gates

### Phase 5: Claude Code Plugin Packaging

**Goal:** Package squashed recipe output as a Claude Code plugin (skills/, commands/, agents/, hooks, .mcp.json) so distribution uses the native format instead of ruly-specific file writing; resolve whether plugins can carry always-on instructions.
**Requirements**: TBD
**Depends on:** Phase 4
**Plans:** 3/3 plans executed

Plans:
**Wave 1**
- [x] 05-01-PLAN.md — `-a claude-plugin` writes a strict-valid plugin dir: manifest + `<recipe>-rules` skill + scripts (tracer), ownership marker, guards, marker-gated clean, `-i`/`-I`, dry run

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 05-02-PLAN.md — Skills, commands, subagents (plugin frontmatter), hooks/hooks.json, .mcp.json with literal-secret warning, `${CLAUDE_PLUGIN_ROOT}` script paths, skipped-parts notice

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 05-03-PLAN.md — README Claude Code Plugin Output section (always-on finding), 0.4.0 + CHANGELOG, phase-closing gates

### Phase 6: Token and Compliance Benchmark

**Goal:** Independently measure the self-reported 85% token-reduction claim and rule compliance/task success of recipe-scoped output vs. native path-scoped rules + skills.
**Requirements**: TBD
**Depends on:** Phase 5
**Plans:** 2/3 plans executed

Plans:
- [x] 06-01-PLAN.md
- [x] 06-02-PLAN.md
- [ ] 06-03-PLAN.md
- [ ] TBD (run /gsd-plan-phase 6 to break down)

### Phase 7: Competitor Composition Audit

**Goal:** Verify whether Ruler's and rulesync's composition models (nesting, includes, profiles) offer task-scoped selection comparable to recipes + `requires:`; feed results into Phase 3 positioning.
**Requirements**: TBD
**Depends on:** Phase 6
**Plans:** 1/1 plans complete

Plans:
- [x] 07-01-PLAN.md
