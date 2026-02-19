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

### TOON Output Format

- [ ] Add `--toon` flag to convert CLAUDE.local.md to TOON format for token efficiency
  - **Use Case**: TOON format is more token-efficient than markdown; useful when context size is a concern
  - **Command**: `ruly squash --toon` or `ruly import --toon`
  - **Behavior**:
    - After generating CLAUDE.local.md, convert to TOON format
    - Output to CLAUDE.local.toon (or replace .md with .toon extension)
    - Requires `npx @toon-format/cli` to be available
  - **Components Needed**:
    - CLI flag parsing for `--toon`
    - Post-processing step to run TOON conversion
    - Fallback behavior if npx/@toon-format/cli not available

### Directives / Skill-Commands

- [ ] Add the option for "directives" or "skill-commands" - a pattern where you can write a directive that can be added to a recipe as either a skill or a subagent
  - **Use Case**: Skills become more reliable because agents are coerced into using them correctly; subagents get explicit instructions on what success/failure looks like
  - **Structure**: Each directive is composed of 2 files:
    1. **Skill file** - The actual skill/command (can also serve as subagent instructions)
       - Example: `comms/commands/context-fetching.md`
       - Invoked via `/context-fetching` or as a subagent prompt
    2. **Standard file** - Explains how the skill/subagent works and coerces the agent into using it correctly
       - Example: `comms/context-fetcher-subagent.md`
       - Contains stronger restrictions, failure conditions, and explicit recommendations
       - Always loaded when the skill is in the recipe
       - Forces proper usage patterns (e.g., "dispatch subagent instead of running commands yourself")
  - **Example Directory Structure**:
    ```
    comms/
    ├── commands/
    │   └── context-fetching.md      # The skill (user-invocable)
    ├── context-fetcher-subagent.md  # The standard (how the subagent must behave)
    └── use-context-fetcher.md       # Enforcement (blocks direct command usage)
    ```
  - **Implementation Ideas**:
    - New frontmatter field: `standard: ./context-fetcher-subagent.md`
    - When squashing a skill, automatically include its standard file
    - Recipe config could specify: `directives: [context-fetching]` which loads both files
  - **Benefits**:
    - Clear separation between "what" (skill) and "how" (standard)
    - The "standard" file acts as guardrails that are always present when the skill is loaded

### PR Review Fixer Agent

- [ ] Build an agent that scans all open PRs, finds unresolved review comments, and auto-fixes them
  - **Use Case**: After reviews come in across multiple PRs, run one command to address all unresolved feedback instead of manually switching between branches
  - **Workflow**:
    1. List all open PRs (authored by `@me`)
    2. For each PR, fetch unresolved review threads
    3. For each unresolved comment, check out the branch and attempt a fix
    4. Commit, push, and reply to the comment with the fix details
    5. Mark thread as resolved
  - **Architecture**:
    - Orchestrator agent lists PRs and parses unresolved comments into discrete tasks
    - Uses parallel fix dispatch pattern (one worktree per PR branch)
    - Each fix agent gets: file path, line range, reviewer comment, suggested fix (if any)
    - Ralph loop for retries (fresh agent per attempt, progress.txt for continuity)
  - **Command**: `/fix-all-reviews` or `/review-sweep`
  - **Safety**:
    - Preview mode: show what would be fixed before executing
    - Skip comments that require architectural decisions (flag for manual review)
    - Only fix comments with clear, actionable feedback
  - **Components Needed**:
    - PR listing + unresolved thread extraction
    - Comment classification (auto-fixable vs needs-human)
    - Parallel worktree checkout per PR branch
    - Fix dispatch using existing parallel fix orchestration pattern
    - Comment reply + thread resolution

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

### Contacts MCP / External Team Directory

- [ ] Replace `accounts.md` with an external contacts lookup system to eliminate ~5K tokens from context
  - **Problem**: `accounts.md` is a 180-line markdown table loaded into context whenever comms rules are active. Most of that data (Jira IDs, Teams IDs, GitHub handles, squads) is only needed at lookup time, not always.
  - **Use Case**: Instead of burning context tokens on a static directory, agents look up contacts on demand via an MCP tool or CLI command
  - **Options**:
    1. **Contacts MCP server** - Custom MCP that serves team directory from a JSON/SQLite file
       - Tools: `contacts_lookup(name)`, `contacts_by_squad(squad)`, `contacts_by_role(role)`
       - Returns: Jira ID, GitHub handle, Teams ID, Mattermost ID, squad, role
       - Source of truth: JSON file synced via chezmoi (replaces accounts.md)
    2. **CLI command** - `ruly contacts lookup "Patrick Clery"` returns all IDs
       - Simpler to implement, agents call via Bash tool
       - Less discoverable than MCP but no server to run
    3. **Hybrid** - Keep a minimal accounts.md with just names + squads (for context), full IDs via MCP lookup
       - Best of both: agents know who's on which squad without lookup, but IDs are fetched on demand
  - **Migration Path**:
    - Extract accounts.md table into structured data (JSON/YAML)
    - Build MCP server or CLI with lookup commands
    - Update comms rules to use lookup instead of referencing the table directly
    - Remove accounts.md from recipes (or replace with minimal version)
    - Update `use-context-grabber.md` and comms subagent to use lookup
  - **Token Savings**: ~5,000 tokens eliminated from every comms-enabled recipe
  - **Components Needed**:
    - Structured data file (JSON/YAML) for team directory
    - MCP server or CLI tool for lookups
    - Migration of all rules that reference accounts.md
    - Sync mechanism (chezmoi or similar)

## Completed Features

- [x] shell_gpt/sgpt agent support for JSON output
- [x] Proper JSON escaping for markdown content
- [x] Requires deduplication to prevent duplicate file inclusion
- [x] Path normalization for consistent file references
