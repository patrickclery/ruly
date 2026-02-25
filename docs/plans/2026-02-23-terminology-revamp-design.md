# Terminology Revamp: Cooking → People

## Goal

Replace Ruly's cooking-inspired terminology with people/role-oriented language that aligns with Claude Code's native ecosystem. Keep all Claude Code native terms (skills, commands, subagents, hooks, MCP servers). Clean break — no backward compatibility.

## Rename Map

| Current | New | Scope |
|---------|-----|-------|
| profile | **profile** | YAML keys, CLI flags, Ruby classes, docs |
| plan | **tier** | YAML key, Ruby code, contexts.yml |
| bins | **scripts** | YAML key, Ruby code, output path |
| `profiles.yml` | **`profiles.yml`** | Config files (project + `~/.config/ruly/`) |
| `.claude/scripts/` | **`.claude/scripts/`** | Output directory |
| `.ruly/` | **removed** | Directory no longer needed |

### Unchanged Terms

squash, dispatches, essential, skills, commands, subagents, MCP servers, hooks, sources, files, requires, model

## CLI Changes

| Current | New |
|---------|-----|
| `ruly squash --profile X` | `ruly squash --profile X` |
| `ruly list-profiles` | `ruly list-profiles` |
| `ruly analyze --profile X` | `ruly analyze --profile X` |
| `ruly import RECIPE` | `ruly import PROFILE` |
| `ruly stats [RECIPE]` | `ruly stats [PROFILE]` |
| `ruly clean --profile X` | `ruly clean --profile X` |

The `-r` shorthand flag stays (works as shorthand for `--profile`).

Unchanged commands: `ruly mcp`, `ruly introspect`, `ruly init`.

## YAML Structure (profiles.yml)

```yaml
tier: claude_pro

profiles:
  workaxle-bug:
    description: "WorkAxle bug investigation"
    files:
      - /path/to/rules/file.md
    sources:
      - github: owner/repo
        branch: main
        rules: [path/to/file.md]
    scripts:
      - /path/to/deploy.sh
    skills:
      - /path/to/skill.md
    commands:
      - /path/to/command.md
    subagents:
      - name: core_engineer
        profile: core-engineer
        model: opus
    mcp_servers:
      - task-master-ai
    model: sonnet
    tier: claude_max
```

### Frontmatter Key

Rule files that auto-include in profiles:

```yaml
---
profiles:
  - workaxle-bug
  - workaxle-testing
---
```

## Ruby Code Changes

### Class/File Renames

| Current | New |
|---------|-----|
| `services/profile_loader.rb` | `services/profile_loader.rb` |
| `Services::ProfileLoader` | `Services::ProfileLoader` |
| `load_profile_sources()` | `load_profile_sources()` |
| All `profile` variables/params | `profile` |

### Output Path Changes

| Current | New |
|---------|-----|
| `.claude/scripts/{script}.sh` | `.claude/scripts/{script}.sh` |

### contexts.yml

`plan:` key → `tier:` key in the YAML structure and all code that reads it.

## File Changes Required

### Config Files

1. `profiles.yml` → `profiles.yml` (project root)
2. `~/.config/ruly/profiles.yml` → `~/.config/ruly/profiles.yml`
3. `~/.config/ruly/mcp.json` (unchanged)

### Documentation

1. `CLAUDE.md` — update all references from profiles.yml to profiles.yml, profile to profile
2. `.claude/ruly-profiles-mcp-patterns.md` — rename/rewrite for profiles terminology
3. `README.md` — update all terminology
4. Memory files — update MEMORY.md references

### Ruby Source Files

Every file in `lib/ruly/` that references profile, plan (as tier), or scripts:

- `lib/ruly/cli.rb`
- `lib/ruly/services/profile_loader.rb` → `profile_loader.rb`
- `lib/ruly/services/source_processor.rb`
- `lib/ruly/services/subagent_processor.rb`
- `lib/ruly/services/script_manager.rb`
- `lib/ruly/services/squash_helpers.rb`
- `lib/ruly/operations/analyzer.rb`
- `lib/ruly/operations/stats.rb`
- `lib/ruly/contexts.yml`
- All spec files

### Rules Source Files

Any rule files with `profiles:` frontmatter → `profiles:` frontmatter.

## Migration Approach

**Clean break.** Major version bump. No backward compatibility aliases or deprecation warnings. Old `profiles.yml` files will fail with a clear error message suggesting the rename.

## Output Directory Structure (After)

```
project/
├── CLAUDE.local.md
├── .mcp.json
├── .claude/
│   ├── agents/{name}.md
│   ├── commands/{path}.md
│   ├── scripts/{script}.sh    # NEW location (was .claude/scripts/)
│   └── skills/{name}/SKILL.md
└── profiles.yml                # NEW name (was profiles.yml)
```
