# Ruly TODO List

## Features

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