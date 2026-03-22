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
- ✓ Multi-agent output (Claude, Cursor, Shell-GPT) — existing
- ✓ Token counting and stats reporting — existing
- ✓ Post-squash validation checks — existing
- ✓ Subagent recipe processing — existing
- ✓ MCP server configuration from recipes — existing
- ✓ Command and script file management — existing
- ✓ Recipe introspection and init — existing
- ✓ Cache support for compiled output — existing

### Active

(None yet — blank slate for future features)

### Out of Scope

(No exclusions defined yet)

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
*Last updated: 2026-03-22 after initialization*
