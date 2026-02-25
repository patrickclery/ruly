# Ruly Profiles and MCP Server Configuration Patterns

## Description

This document captures essential patterns and rules for configuring Ruly profiles with MCP (Model Context Protocol) servers, based on the WorkAxle optimization project that achieved 85% token reduction through conditional documentation loading.

## Key Patterns

### 1. Path Specification Rules

**Critical Rule**: Ruly does NOT support glob patterns or wildcards in profile paths.

```yaml
# ❌ WRONG - Glob patterns don't work
files:
  - rules/workaxle/**/*.md  # Won't work
  - rules/workaxle/core/frameworks/rspec-*.md  # Won't work

# ✅ CORRECT - Use absolute paths
files:
  - /Users/patrick/Projects/ruly/rules/workaxle/core.md
  - /Users/patrick/Projects/ruly/rules/workaxle/core/bug/
```

### 2. Directory vs File Specification

**Rule**: Use directory paths when including ALL files in a directory, use specific file names for selective includes.

```yaml
# ✅ Use directory path when including all files
files:
  - /Users/patrick/Projects/ruly/rules/workaxle/core/bug/  # Includes all .md files

# ✅ List specific files when being selective
files:
  - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/rspec-basics.md
  - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/rspec-sequel.md
  - /Users/patrick/Projects/ruly/rules/workaxle/core/frameworks/rspec-factories.md
```

### 3. MCP Server Selection

Choose MCP servers based on the specific task requirements:

**Note**: Jira operations now use the `jira` CLI (jira-cli). The `atlassian` MCP is only needed for Confluence page creation.

```yaml
# Bug Investigation (Jira uses CLI, not MCP)
mcp_servers:
  - task-master-ai  # Task management and workflow tracking
  - teams           # For Teams DM notifications

# Testing
mcp_servers:
  - playwright      # For UI/integration testing
  - task-master-ai  # Task management and workflow tracking

# Confluence Operations (only case needing atlassian MCP)
mcp_servers:
  - atlassian       # For Confluence page creation only
  - task-master-ai  # Task management and workflow tracking
```

### 4. Model Specification

Assign models to subagents for cost/speed optimization:

```yaml
subagents:
  - name: context_grabber
    profile: context-grabber
    model: haiku          # Lightweight fetch tasks
  - name: core_engineer
    profile: core-engineer
    model: opus           # Complex implementation
  - name: comms
    profile: comms
    # Omitted — inherits from profile 'model' or defaults to 'inherit'
```

Profile-level default:
```yaml
core:
  model: sonnet           # All subagents default to sonnet
  subagents:
    - name: fast_agent
      profile: fast
      model: haiku        # Override: haiku beats sonnet here
```

Inheritance chain: subagent `model` > profile `model` > `inherit`

## Examples

### Complete WorkAxle Profile Example

```yaml
workaxle-bug:
  description: "WorkAxle bug investigation and fixing"
  files:
    - /Users/patrick/Projects/ruly/rules/workaxle/core.md
    - /Users/patrick/Projects/ruly/rules/workaxle/profiles/bug-investigation.md
    - /Users/patrick/Projects/ruly/rules/bug/
    - /Users/patrick/Projects/ruly/rules/workaxle/commands/diagnose.md
    - /Users/patrick/Projects/ruly/rules/workaxle/commands/fix.md
  mcp_servers:
    - task-master-ai  # Task management and workflow tracking
    - teams           # For Teams DM notifications
    # Note: Jira uses CLI (jira issue view, jira issue move, etc.)
```

### Task-Specific Profiles

```yaml
# Final Review Stage Profile (with Confluence access)
workaxle-review:
  description: "WorkAxle final review and QA stage"
  files:
    - /Users/patrick/Projects/ruly/rules/workaxle/core.md
    - /Users/patrick/Projects/ruly/rules/github/pr/
    - /Users/patrick/Projects/ruly/rules/workaxle/core/testing/
    - /Users/patrick/Projects/ruly/rules/comms/  # Includes jira, confluence
  mcp_servers:
    - atlassian       # For Confluence page creation only
    - playwright      # UI testing and demos
    - task-master-ai  # Task management and workflow tracking
```

## Best Practices

### 1. Profile Organization

- **Create task-specific profiles** rather than loading everything
- **Use `workaxle-core`** as the base with minimal always-loaded files
- **Extend with focused profiles** for specific workflows (bug, testing, PR, etc.)

### 2. MCP Server Assignment

- **Minimal servers per profile** - Only include what's actually needed
- **Document the purpose** - Add comments explaining why each server is included
- **Consider task flow** - Think about the actual workflow when selecting servers

### 3. File Synchronization

**Critical**: Always update BOTH profile files when making changes:

1. `/Users/patrick/Projects/ruly/profiles.yml` - Project profiles
2. `/Users/patrick/.config/ruly/profiles.yml` - User config

### 4. Token Optimization

- **Only `core.md` should have `alwaysApply: true`** in the actual rule files
- **Use profiles to conditionally load** documentation based on current task
- **Achieved 85% token reduction** through this approach

## Anti-patterns

### 1. ❌ Using Glob Patterns

```yaml
# NEVER DO THIS - Ruly doesn't support glob patterns
files:
  - rules/**/*.md
  - rules/workaxle/core/frameworks/rspec-*.md
```

### 2. ❌ Loading Everything by Default

```yaml
# AVOID - This defeats token optimization
workaxle:
  files:
    - /Users/patrick/Projects/ruly/rules/workaxle/  # Too broad for most tasks
```

### 3. ❌ Relative Paths

```yaml
# WRONG - Must use absolute paths
files:
  - rules/workaxle/core.md  # Missing full path
```

### 4. ❌ Unnecessary MCP Servers

```yaml
# WRONG - Including atlassian when only Jira (not Confluence) is needed
workaxle-bug:
  mcp_servers:
    - atlassian   # WRONG - Jira now uses CLI, atlassian only for Confluence
    - grafana     # Not needed for bug fixing
    - playwright  # Not needed for bug fixing
```

## Related Files

### Profile Configuration Files

- `/Users/patrick/Projects/ruly/profiles.yml` - Main project profiles
- `/Users/patrick/.config/ruly/profiles.yml` - User configuration (must match)
- `/Users/patrick/Projects/ruly/rules/workaxle/profile-config.yml` - WorkAxle profile definitions

### Documentation Files

- `/Users/patrick/Projects/ruly/rules/workaxle/OPTIMIZATION-README.md` - Token optimization guide
- `/Users/patrick/Projects/ruly/rules/workaxle/core.md` - Core WorkAxle patterns (only file with alwaysApply: true)

### Available MCP Servers

- `atlassian` - **Confluence page creation only** (Jira operations use `jira` CLI)
- `circleci` - CI/CD pipeline management
- `grafana` - Metrics and monitoring
- `jetbrains` - JetBrains IDE integration
- `memory` - Persistent memory storage
- `plane` - Plane project management
- `playwright` - Browser automation and UI testing
- `Ref` - Documentation reference lookup
- `task-master-ai` - Task management and workflow tracking
- `teams` - Microsoft Teams integration

### Jira CLI Commands (replaces atlassian MCP for Jira)

```bash
# View issue details
jira issue view WA-1234

# Transition issue status
jira issue move WA-1234 "Ready for QA"

# Add comment (simple)
jira issue comment add WA-1234 "comment"

# For comments with @mentions, use post-jira-comment.sh
post-jira-comment.sh WA-1234 "markdown with [@Name](mention:ID)"
```

## Usage Commands

```bash
# Import a specific profile
ruly import --profile workaxle-bug

# Squash a profile for testing (run from temp directory)
cd $(mktemp -d)
ruly squash --profile workaxle-testing

# List available profiles
ruly list-profiles

# Update installed ruly after changes
mise install ruby
```

## Key Achievements

- **85% token reduction** from ~15,000 tokens to ~2,000 tokens base usage
- **Conditional loading** based on file patterns and task profiles
- **MCP server integration** for automated tool availability
- **Task-specific profiles** for focused workflows

## Important Notes

1. When updating profiles, always update both the project and user config files
2. Test profile changes using `ruly squash` in a temporary directory
3. Update the installed ruly binary after making changes to the gem
4. WorkAxle profiles follow a naming convention: `workaxle-[task]` (e.g., workaxle-bug, workaxle-testing)
5. The `workaxle-full` profile exists for rare cases when complete documentation is needed
