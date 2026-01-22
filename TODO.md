# Ruly TODO List

## Features

### Optional Files in Recipes

- [ ] Add ability to mark files as optional in a recipe, prompting user for confirmation
  - **Use Case**: Some rules are situationally useful but add tokens; let users decide at import/squash time
  - **Syntax Ideas**:
    ```yaml
    files:
      - /path/to/required-file.md
      - optional: /path/to/optional-file.md
      # or
      - path: /path/to/optional-file.md
        optional: true
        description: "Include advanced debugging patterns?"
    ```
  - **Behavior**:
    - Prompt user with `Include [description]? (Y/n)` for each optional file
    - `--yes` flag to include all optional files without prompting
    - `--no-optional` flag to skip all optional files without prompting
  - **Components Needed**:
    - Recipe parser update to handle optional file syntax
    - Interactive prompt system
    - CLI flags for non-interactive mode

### Auto-Exclude Diff Based on Token Count

- [ ] Update `fetch-pr-details.sh` to automatically exclude diff when output exceeds token limit
  - **Use Case**: Instead of requiring `--without-diff` flag, automatically detect when output is too large
  - **File**: `rules/github/pr/hooks/fetch-pr-details.sh`
  - **Behavior**:
    - Remove `--without-diff` option
    - After fetching PR data with diff, count tokens
    - If token count > 25000 (Claude Code's per-message limit), re-fetch without diff
    - Display message: "Diff excluded (output would exceed 25000 tokens)"
  - **Token Counting Options**:
    - Simple: `wc -c` / 4 (rough estimate: ~4 chars per token)
    - Better: Use `tiktoken` or similar tokenizer if available
    - Best: Use Claude's tokenizer API if accessible
  - **Components Needed**:
    - Token counting function
    - Conditional diff inclusion logic
    - User feedback when diff is excluded

### Malformed Frontmatter/Markdown Warnings

- [ ] Add warnings for malformed frontmatter or markdown that could affect squash interpretation
  - **Use Case**: Files with invalid YAML frontmatter (e.g., closing `---` not on its own line) silently pass through unprocessed, causing unexpected content in output
  - **Checks to Implement**:
    - Frontmatter closing `---` must be on its own line (not `value---`)
    - Valid YAML syntax in frontmatter block
    - Unclosed code blocks that could swallow content
    - Mismatched markdown headers
  - **Behavior**:
    - Display warning during squash with file path and issue description
    - Suggest fix or auto-fix with `--fix-frontmatter` flag
    - `--strict` flag to fail on any malformed content
  - **Components Needed**:
    - Frontmatter validation check before stripping
    - Markdown linting for common issues
    - Warning output formatting

### Context Switching Workflow

- [ ] Add ability to create one set of rules to execute a command, then clear the context and restart Claude with a different set of rules
  - **Use Case**: Load Atlassian MCP to get task details and create a plan, save the plan, then clear context and restart Claude Code with different rules for implementation
  - **Implementation Ideas**:
    - Add a `--chain` or `--workflow` flag to chain multiple rule sets
    - Support for saving intermediate outputs between context switches
    - Ability to pass data from one context to the next
    - Command like: `ruly workflow task-planning implementation --save-between`
  - **Components Needed**:
    - Workflow definition format (YAML/JSON)
    - Context clearing mechanism
    - State persistence between contexts
    - Rules for transitioning between contexts

## Completed Features

- [x] shell_gpt/sgpt agent support for JSON output
- [x] Proper JSON escaping for markdown content
- [x] Requires deduplication to prevent duplicate file inclusion
- [x] Path normalization for consistent file references
