# Ruly

## What This Is

Ruly is a Ruby gem and CLI tool that compiles modular markdown rule files into agent-specific instruction documents (CLAUDE.md, .cursorrules, etc.). It uses a recipe system to compose the right rules for the right context, with dependency resolution, remote GitHub file fetching, and multi-agent support.

## Core Value

Rules get squashed correctly into agent instruction files every time — reliable, deterministic compilation is the foundation everything else depends on.

## Requirements

### Validated

- ✓ Squash recipe into merged markdown output — existing
- ✓ Recipe system with YAML definitions and user overrides — existing
- ✓ Dependency resolution via `requires:` and `skills:` frontmatter — existing
- ✓ Remote file fetching from GitHub repositories — existing
- ✓ Multi-agent output (Claude, Cursor) — existing; Shell-GPT JSON removed Phase 2
- ✓ AGENTS.md output target (`-a agents`, marker-gated clean/overwrite guard) — Phase 4 (0.3.0)
- ✓ Token counting and stats reporting — existing; `analyze` folded into `stats` Phase 2
- ✓ Post-squash validation checks — existing
- ✓ Subagent recipe processing — existing
- ✓ MCP server configuration from recipes — existing (standalone `ruly mcp` removed Phase 2)
- ✓ Command and script file management — existing
- ✓ Recipe introspection and init — existing

### Active

(None yet — blank slate for future features)

### Out of Scope

- `ruly import` command — removed Phase 2; `squash` already copies scripts
- `ruly analyze` command / context-window tiers — folded into `stats` Phase 2
- Standalone `ruly mcp` command — removed Phase 2; use recipe `mcp_servers:` or `claude mcp add`
- `--cache` compiled-output cache — removed Phase 2; manual invalidation, squash is fast
- TaskMaster integration flags — removed Phase 2; unrelated to rule composition
- Shell-GPT JSON role output — removed Phase 2; AGENTS.md (Phase 4) is the cross-agent path

## Context

- Published Ruby gem on RubyGems (MFA required)
- Built on Thor CLI framework with modular service architecture
- Has a Next.js documentation site (`site/`) deployed to GitHub Pages
- Uses `gh` CLI for GitHub API operations (no embedded tokens)
- Rules stored in a git submodule (`rules/`)
- User config at `~/.config/ruly/recipes.yml` overrides base `recipes.yml`
- Comprehensive RSpec test suite with WebMock for HTTP mocking
- Lefthook for git hooks, RuboCop for linting

## Constraints

- **Runtime**: Ruby 3.3.0+ required
- **CLI dependency**: Relies on `gh` CLI for GitHub integration
- **Token counting**: Uses `tiktoken_ruby` which has native extensions

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Thor for CLI | Mature, well-documented Ruby CLI framework | ✓ Good |
| Git submodule for rules | Separate repo allows sharing rules across projects | ✓ Good |
| YAML frontmatter for metadata | Standard markdown convention, easy to parse | ✓ Good |
| GraphQL batch prefetch | Reduces API calls when fetching remote files | ✓ Good |
| Lean out native duplication (0.2.0) | Claude Code natively covers MCP/plugins; keep composition as ruly's core | ✓ Phase 2 |
| Hard removal, no deprecation window | Single maintainer, no forks | ✓ Phase 2 |
| Thor `check_unknown_options!` class-wide | Removed switches must fail loudly, not be read as recipe names | ✓ Phase 2 |
| Unknown/removed recipe keys warn and continue | Don't break shared recipes across machines | ✓ Phase 2 |
| AGENTS.md as the cross-agent path (no per-agent adapters) | Reach Ruler/rulesync-covered agents via the standard | ✓ Phase 4 |
| `-i`/`-I` merge into the Ruly ignore section | Targets must not un-ignore each other's output | ✓ Phase 4 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-11-02 after Phase 4*
