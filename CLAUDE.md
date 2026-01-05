- always update the ~/.config/ruly/recipes.yml and /Users/patrick/Projects/chezmoi/config/ruly/recipes.yml when you change things it references (they should be identical)
- Every time the slash commands are updated. Make sure to update the slash command Section of the read me
- When I ask to change rules, don't change the rules in .claude/ always look in ./rules/

# Claude Code Instructions

## Ruly Recipe and MCP Configuration Patterns

**Import Ruly recipe configuration patterns and MCP server guidelines.**
@./.claude/ruly-recipes-mcp-patterns.md

- When testing out `ruly squash ...`, always run it from a `mktmpdir` and not the main project directory
- always update ruly after any changes. for instance, /Users/patrick/.local/share/mise/installs/ruby/3.3.3/bin/ruly is out of sync right now

## CRITICAL: Never Reference Filenames in Rules

**Filenames do not exist after `ruly squash`.** When rules are squashed, all files are merged into a single output. References to filenames like `preview-common.md` or `accounts.md` will be meaningless.

**ALWAYS use markdown section links instead.**

### BAD (filename references)

```markdown
See `preview-common.md` for details.
Follow the workflow in `accounts.md`.
Review `preview-common.md` before submitting.
```

### GOOD (section anchor links)

```markdown
See [Jira Draft Preview Workflow](#jira-draft-preview-workflow) for details.
Follow the workflow in [Jira Accounts](#jira-accounts).
Review [Jira Draft Preview Workflow](#jira-draft-preview-workflow) before submitting.
```

**Why this matters:** After squashing, the section headers remain as anchor targets, but filenames disappear completely.
