# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-11-02

Ruly drops commands, flags and outputs that are unrelated to rule composition or duplicate native
Claude Code features. Removals are immediate, with no deprecation period.

### Removed

- `ruly import` command. `ruly squash` already copies recipe scripts to `.claude/scripts/`.
- `ruly analyze` command and its `--tier` / `--all` options. Use `ruly stats`, which now prints the
  console token summary.
- `ruly mcp` command. Choose MCP servers per recipe with `mcp_servers:` (written to `.mcp.json` by
  `ruly squash`), or use Claude Code's `claude mcp add`.
- `squash --cache` and its cache output (`cache/<agent>/<recipe>.md`, `~/.cache/ruly/`).
- The `-T` / `--taskmaster-config` flag on `squash` and `clean`, and `squash --keep-taskmaster`,
  including the `.taskmaster/` config copy and import.
- Shell-GPT role-JSON output. `-a shell_gpt` and `-a sgpt` now produce plain markdown, like other
  non-Claude agents, and print a notice on stderr saying so.
- The `tier` recipe and config key, and `lib/ruly/contexts.yml` (context-window tier percentages).

### Changed

- Unknown CLI switches now exit 1 with `Unknown switches` instead of being ignored.
- `ruly squash` warns on stderr about removed or unknown recipe keys (for example `tier`, `cache`)
  and continues. A top-level `tier:` in the recipes config file warns the same way.
- `ruly stats` is the single token-reporting command.
- `ruly list-recipes` no longer prints a `Tier:` line.

### Fixed

- `ruly stats` no longer aborts when no recipe source is configured. It writes `stats.md` for the
  local rule files and warns on stderr that recipe totals are skipped.

## [0.1.0] - 2024-08-19

### Added

- Initial release of Ruly as a Ruby gem
- `ruly import` command to generate CLAUDE.local.md with @import statements
- `ruly squash` command to combine all markdown files into one
- `ruly list-recipes` command to list available recipe collections
- `ruly init` command to initialize ruly in a project
- `ruly version` command to show the version
- Recipe-based compilation system with YAML configuration
- Support for Claude and Cursor AI assistants
- Caching system for recipe compilation
- Command file separation for Claude assistant

### Changed

- Migrated from shell script installer to Ruby gem distribution
- Changed from symlink-based system to gem-based distribution
- Made `ruly` available in PATH when installed as a gem

### Removed

- Shell script installer (install.sh)
- Symlink-based global rules system
- Direct file system manipulation approach
