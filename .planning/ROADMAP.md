# Roadmap: Ruly

## Overview

Ruly is a mature Ruby gem and CLI tool with all foundational capabilities already shipped. The squash pipeline, recipe system, multi-agent output, GitHub integration, and CLI commands are complete and in production use. This roadmap captures the existing state and serves as the anchor for future feature phases added via `/gsd:add-phase`.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Platform** - Squash pipeline, recipe system, multi-agent output, GitHub integration, and CLI (existing/complete)

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
