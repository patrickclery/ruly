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

1. Command files whose path (after `rules/` and before `/commands/`) starts with the prefix will have that prefix removed
2. Other command files retain their original structure

### Example

With `omit_command_prefix: workaxle/core`:

- `rules/workaxle/core/testing/commands/pre-commit.md` → `.claude/commands/testing/pre-commit.md`
- `rules/workaxle/core/testing/commands/require.md` → `.claude/commands/testing/require.md`
- `rules/workaxle/atlassian/jira/commands/details.md` → `.claude/commands/workaxle/atlassian/jira/details.md`

The prefix is only removed from paths that match it exactly from the beginning.

## Introspect Support

The `omit_command_prefix` key is preserved when using the `introspect` command to update a recipe. This ensures your path simplification preferences are maintained when adding new files to an existing recipe.

## Use Cases

This feature is particularly useful for:

- Large monorepo projects where commands are deeply nested by team/project
- Simplifying command access when a specific context is always assumed
- Creating cleaner command structures without reorganizing source files
