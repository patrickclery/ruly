# omit_command_prefix Feature

## Overview

The `omit_command_prefix` feature allows you to strip a common prefix from command file paths when they are saved to `.claude/commands/`. This is useful when you have deeply nested command structures that you want to flatten for easier access.

## Usage

Add the `omit_command_prefix` key to your recipe configuration in `recipes.yml`:

```yaml
recipes:
  my_recipe:
    description: My recipe with simplified command paths
    omit_command_prefix: path/to/strip
    files:
      - rules/path/to/strip/commands/feature.md
      - rules/other/path/commands/tool.md
```

## How It Works

When `omit_command_prefix` is set:

1. Command files whose path (after `rules/` and before `/commands/`) starts with any part of the prefix will have the matching parts removed
2. This handles both complete and partial prefix matches
3. Other command files that don't match the prefix retain their original structure

### Example

With `omit_command_prefix: workaxle/core`:

- `rules/workaxle/core/testing/commands/pre-commit.md` → `.claude/commands/testing/pre-commit.md` (full prefix matched and removed)
- `rules/github/pr/commands/create.md` → `.claude/commands/github/pr/create.md` (no match, retains structure)
- `rules/workaxle/atlassian/jira/commands/details.md` → `.claude/commands/atlassian/jira/details.md` (partial prefix "workaxle" matched and removed)
- `rules/other/project/commands/tool.md` → `.claude/commands/other/project/tool.md` (no match, retains structure)

The prefix removal works by matching path components from the beginning, removing any parts that match the prefix components.

## Introspect Support

The `omit_command_prefix` key is preserved when using the `introspect` command to update a recipe. This ensures your path simplification preferences are maintained when adding new files to an existing recipe.

## Use Cases

This feature is particularly useful for:

- Large monorepo projects where commands are deeply nested by team/project
- Simplifying command access when a specific context is always assumed
- Creating cleaner command structures without reorganizing source files

## Important Notes

### Reserved Directory Names

**WARNING**: Avoid using `debug` as a directory name for commands. Claude Code reserves this keyword and commands in `.claude/commands/debug/` will not be recognized as slash commands.

**Recommended alternatives:**

- Use `bug` for bug-related commands (e.g., `/bug:diagnose`, `/bug:fix`)
- Use `troubleshoot` for troubleshooting commands
- Use `investigate` for investigation commands

When Ruly detects a `debug` directory in command paths, it will display a warning during the squash process.
