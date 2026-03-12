# Terminology Revamp: Cooking → People

## Goal

Replace Ruly's cooking-inspired terminology with people/role-oriented language that aligns with Claude Code's native ecosystem. Keep all Claude Code native terms (skills, commands, subagents, hooks, MCP servers). Clean break — no backward compatibility.

## Rename Map

| Current | New | Scope |
|---------|-----|-------|
| recipe | **recipe** | YAML keys, CLI flags, Ruby classes, docs |
| plan | **tier** | YAML key, Ruby code, contexts.yml |
| bins | **scripts** | YAML key, Ruby code, output path |
| `recipes.yml` | **`recipes.yml`** | Config files (project + `~/.config/ruly/`) |
| `.claude/scripts/` | **`.claude/scripts/`** | Output directory |
| `.ruly/` | **removed** | Directory no longer needed |

### Unchanged Terms

squash, dispatches, essential, skills, commands, subagents, MCP servers, hooks, sources, files, requires, model

## CLI Changes

| Current | New |
|---------|-----|
| `ruly squash --recipe X` | `ruly squash --recipe X` |
| `ruly list-recipes` | `ruly list-recipes` |
| `ruly analyze --recipe X` | `ruly analyze --recipe X` |
| `ruly import RECIPE` | `ruly import RECIPE` |
| `ruly stats [RECIPE]` | `ruly stats [RECIPE]` |
| `ruly clean --recipe X` | `ruly clean --recipe X` |

The `-r` shorthand flag stays (works as shorthand for `--recipe`).

Unchanged commands: `ruly mcp`, `ruly introspect`, `ruly init`.

## YAML Structure (recipes.yml)

```yaml
tier: claude_pro

recipes:
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
        recipe: core-engineer
        model: opus
    mcp_servers:
      - task-master-ai
    model: sonnet
    tier: claude_max
```

### Frontmatter Key

Rule files that auto-include in recipes:

```yaml
---
recipes:
  - workaxle-bug
  - workaxle-testing
---
```

## Ruby Code Changes

### Class/File Renames

| Current | New |
|---------|-----|
| `services/recipe_loader.rb` | `services/recipe_loader.rb` |
| `Services::RecipeLoader` | `Services::RecipeLoader` |
| `load_recipe_sources()` | `load_recipe_sources()` |
| All `recipe` variables/params | `recipe` |

### Output Path Changes

| Current | New |
|---------|-----|
| `.claude/scripts/{script}.sh` | `.claude/scripts/{script}.sh` |

### contexts.yml

`plan:` key → `tier:` key in the YAML structure and all code that reads it.

## File Changes Required

### Config Files

1. `recipes.yml` → `recipes.yml` (project root)
2. `~/.config/ruly/recipes.yml` → `~/.config/ruly/recipes.yml`
3. `~/.config/ruly/mcp.json` (unchanged)

### Documentation

1. `CLAUDE.md` — update all references from recipes.yml to recipes.yml, recipe to recipe
2. `.claude/ruly-recipes-mcp-patterns.md` — rename/rewrite for recipes terminology
3. `README.md` — update all terminology
4. Memory files — update MEMORY.md references

### Ruby Source Files

Every file in `lib/ruly/` that references recipe, plan (as tier), or scripts:

- `lib/ruly/cli.rb`
- `lib/ruly/services/recipe_loader.rb` → `recipe_loader.rb`
- `lib/ruly/services/source_processor.rb`
- `lib/ruly/services/subagent_processor.rb`
- `lib/ruly/services/script_manager.rb`
- `lib/ruly/services/squash_helpers.rb`
- `lib/ruly/operations/analyzer.rb`
- `lib/ruly/operations/stats.rb`
- `lib/ruly/contexts.yml`
- All spec files

### Rules Source Files

Any rule files with `recipes:` frontmatter → `recipes:` frontmatter.

## Migration Approach

**Clean break.** Major version bump. No backward compatibility aliases or deprecation warnings. Old `recipes.yml` files will fail with a clear error message suggesting the rename.

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
└── recipes.yml                # NEW name (was recipes.yml)
```
