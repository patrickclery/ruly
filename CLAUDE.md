- always update the ~/.config/ruly/recipes.yml and /Users/patrick/Projects/chezmoi/config/ruly/recipes.yml when you change things it references (they should be identical)
- Every time the slash commands are updated. Make sure to update the slash command Section of the read me
- When I ask to change rules, don't change the rules in .claude/ always look in ./rules/
- When I ask to create a skill, add it to `rules/{tag}/skills/{skill-name}.md` (Ruly searches for skills in that structure)
- Skills in rules/ are regular `.md` files, NOT `SKILL.md` - Ruly converts them to SKILL.md format on squash
- Always use `git mv` to move/rename files instead of deleting and re-creating them (preserves git history)
- When deleting/moving/renaming files in rules/, always search for references to update:
  - `requires:` frontmatter in other rule files
  - Recipe files (recipes.yml, ~/.config/ruly/recipes.yml)
  - Section anchor links that may have changed
- When I say "commit" or "commit all", commit and push ALL modified files in BOTH repos (don't assume any changes are unrelated):
  1. The rules submodule (./rules) → https://github.com/patrickclery/rules
  2. The parent ruly repo → https://github.com/patrickclery/ruly (update submodule reference)
- Always use **Mermaid** for diagrams/flowcharts in rules (never graphviz/dot). Exception: Jira/Confluence don't support Mermaid, so use ASCII diagrams there instead.

# Claude Code Instructions

## Ruly Recipe and MCP Configuration Patterns

**Import Ruly recipe configuration patterns and MCP server guidelines.**
@./.claude/ruly-recipes-mcp-patterns.md

- When testing out `ruly squash ...`, always run it from a `mktmpdir` and not the main project directory
- always update ruly after any changes. for instance, /Users/patrick/.local/share/mise/installs/ruby/3.3.3/bin/ruly is out of sync right now

## CRITICAL: Never Reference Filenames in Rules

**Filenames do not exist after `ruly squash`.** When rules are squashed, all files are merged into a single output. References to filenames like `preview-common.md` or `accounts.md` will be meaningless.

**ALWAYS use markdown section links instead, and ensure the referenced file is in `requires:`.**

### BAD (filename references)

```markdown
See `preview-common.md` for details.
Follow the workflow in `accounts.md`.
Review `preview-common.md` before submitting.
```

### GOOD (section anchor links + requires)

```yaml
---
requires:
  - ../jira/preview-common.md
  - ../accounts.md
---
```

```markdown
See [Jira Draft Preview Workflow](#jira-draft-preview-workflow) for details.
Follow the workflow in [Jira Accounts](#jira-accounts).
Review [Jira Draft Preview Workflow](#jira-draft-preview-workflow) before submitting.
```

**Why this matters:** After squashing, the section headers remain as anchor targets, but filenames disappear completely. The `requires:` frontmatter ensures the referenced content is included in the squashed output.

## CRITICAL: Never Reference Commands by Name in Rules

**Command names like `/create` or `/merge-to-develop` do not exist after `ruly squash`.** When referencing related commands, use section anchor links instead.

### BAD (command references)

```markdown
- `/pr:review-feedback-loop` - Handle review feedback
- `/create-branch` - Create feature branches
- See `/create-develop` for creating PRs against develop
```

### GOOD (section anchor links + requires)

```yaml
---
requires:
  - ./review-feedback-loop.md
  - ./create-branch.md
  - ./create-develop.md
---
```

```markdown
- [PR Review Feedback Loop](#pr-review-feedback-loop) - Handle review feedback
- [Create Feature Branches](#create-feature-branches) - Create branches with proper naming
- See [Create PR Against Develop](#create-pr-against-develop) for creating PRs against develop
```

**Why this matters:** Slash commands are just file names with `/` prefix - they disappear after squashing just like filenames do.
