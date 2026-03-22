# Requirements: Ruly

**Defined:** 2026-03-22
**Core Value:** Rules get squashed correctly into agent instruction files every time

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Squash Pipeline

- [x] **SQSH-01**: User can squash a recipe into a merged markdown output file
- [x] **SQSH-02**: Squash resolves `requires:` dependencies recursively
- [x] **SQSH-03**: Squash resolves `skills:` dependencies from GitHub
- [x] **SQSH-04**: Squash deduplicates sources by realpath
- [x] **SQSH-05**: Squash strips frontmatter unless `--front-matter` flag used
- [x] **SQSH-06**: Post-squash validation catches ambiguous links and duplicate skill requires

### Recipe System

- [x] **RCPE-01**: User can define recipes in YAML with files, skills, commands, scripts
- [x] **RCPE-02**: User config at `~/.config/ruly/recipes.yml` overrides base recipes
- [x] **RCPE-03**: Recipes support `extends:` for inheritance
- [x] **RCPE-04**: Recipe introspection scans directories to create new recipes

### Multi-Agent Support

- [x] **AGNT-01**: Output supports Claude (markdown), Cursor (.cursorrules), Shell-GPT (JSON)
- [x] **AGNT-02**: Subagent recipes process recursively in subdirectories
- [x] **AGNT-03**: MCP server configuration generated from recipe `mcp_servers:`

### GitHub Integration

- [x] **GHUB-01**: Remote files fetched via GitHub GraphQL API in batch
- [x] **GHUB-02**: Fallback to REST API and `gh` CLI when GraphQL fails

### CLI

- [x] **CLI-01**: `ruly squash` compiles recipe to output
- [x] **CLI-02**: `ruly stats` reports token counts per recipe
- [x] **CLI-03**: `ruly clean` removes generated output files
- [x] **CLI-04**: `ruly import` imports rules from files or URLs
- [x] **CLI-05**: `ruly init` initializes ruly configuration
- [x] **CLI-06**: `ruly analyze` analyzes rule files

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

(None yet -- blank slate)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| (None yet) | No exclusions defined |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SQSH-01 | Phase 1 | Complete |
| SQSH-02 | Phase 1 | Complete |
| SQSH-03 | Phase 1 | Complete |
| SQSH-04 | Phase 1 | Complete |
| SQSH-05 | Phase 1 | Complete |
| SQSH-06 | Phase 1 | Complete |
| RCPE-01 | Phase 1 | Complete |
| RCPE-02 | Phase 1 | Complete |
| RCPE-03 | Phase 1 | Complete |
| RCPE-04 | Phase 1 | Complete |
| AGNT-01 | Phase 1 | Complete |
| AGNT-02 | Phase 1 | Complete |
| AGNT-03 | Phase 1 | Complete |
| GHUB-01 | Phase 1 | Complete |
| GHUB-02 | Phase 1 | Complete |
| CLI-01 | Phase 1 | Complete |
| CLI-02 | Phase 1 | Complete |
| CLI-03 | Phase 1 | Complete |
| CLI-04 | Phase 1 | Complete |
| CLI-05 | Phase 1 | Complete |
| CLI-06 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21/21
- Unmapped: 0

---
*Requirements defined: 2026-03-22*
*Last updated: 2026-03-22 after roadmap creation*
