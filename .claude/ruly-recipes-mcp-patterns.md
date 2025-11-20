# Ruly Recipes and MCP Server Configuration Patterns

## Description

This document captures essential patterns and rules for configuring Ruly recipes with MCP (Model Context Protocol) servers, based on the WorkAxle optimization project that achieved 85% token reduction through conditional documentation loading.

## Key Patterns

### 1. Path Specification Rules

**Critical Rule**: Ruly does NOT support glob patterns or wildcards in recipe paths.

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

```yaml
# Bug Investigation
mcp_servers:
  - atlassian  # For Jira ticket details
  - github     # For code context
  - grafana    # For metrics and monitoring

# Testing
mcp_servers:
  - github      # For code context
  - playwright  # For UI/integration testing

# PR Management
mcp_servers:
  - github     # Essential for PR operations
  - atlassian  # For Jira ticket linking
```

## Examples

### Complete WorkAxle Recipe Example

```yaml
workaxle-bug:
  description: "WorkAxle bug investigation and fixing"
  files:
    - /Users/patrick/Projects/ruly/rules/workaxle/core.md
    - /Users/patrick/Projects/ruly/rules/workaxle/profiles/bug-investigation.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/bug/
    - /Users/patrick/Projects/ruly/rules/workaxle/commands/bug-diagnose.md
    - /Users/patrick/Projects/ruly/rules/workaxle/commands/bug-fix.md
  mcp_servers:
    - atlassian  # For Jira ticket investigation
    - github     # For code/PR context
    - grafana    # For metrics and monitoring
```

### Task-Specific Recipes

```yaml
# Final Review Stage Recipe
workaxle-review:
  description: "WorkAxle final review and QA stage"
  files:
    - /Users/patrick/Projects/ruly/rules/workaxle/core.md
    - /Users/patrick/Projects/ruly/rules/workaxle/pr/
    - /Users/patrick/Projects/ruly/rules/workaxle/commands/pr-create.md
    - /Users/patrick/Projects/ruly/rules/workaxle/commands/pr-comments.md
    - /Users/patrick/Projects/ruly/rules/workaxle/core/testing/
  mcp_servers:
    - github      # PR management and reviews
    - atlassian   # Jira status updates
    - playwright  # UI testing and demos
```

## Best Practices

### 1. Recipe Organization

- **Create task-specific recipes** rather than loading everything
- **Use `workaxle-core`** as the base with minimal always-loaded files
- **Extend with focused recipes** for specific workflows (bug, testing, PR, etc.)

### 2. MCP Server Assignment

- **Minimal servers per recipe** - Only include what's actually needed
- **Document the purpose** - Add comments explaining why each server is included
- **Consider task flow** - Think about the actual workflow when selecting servers

### 3. File Synchronization

**Critical**: Always update BOTH recipe files when making changes:

1. `/Users/patrick/Projects/ruly/recipes.yml` - Project recipes
2. `/Users/patrick/.config/ruly/recipes.yml` - User config

### 4. Token Optimization

- **Only `core.md` should have `alwaysApply: true`** in the actual rule files
- **Use recipes to conditionally load** documentation based on current task
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
# WRONG - Including servers not needed for the task
workaxle-refactor:
  mcp_servers:
    - atlassian   # Not needed for refactoring
    - grafana     # Not needed for refactoring
    - playwright  # Not needed for refactoring
```

## Related Files

### Recipe Configuration Files

- `/Users/patrick/Projects/ruly/recipes.yml` - Main project recipes
- `/Users/patrick/.config/ruly/recipes.yml` - User configuration (must match)
- `/Users/patrick/Projects/ruly/rules/workaxle/recipe-config.yml` - WorkAxle recipe definitions

### Documentation Files

- `/Users/patrick/Projects/ruly/rules/workaxle/OPTIMIZATION-README.md` - Token optimization guide
- `/Users/patrick/Projects/ruly/rules/workaxle/core.md` - Core WorkAxle patterns (only file with alwaysApply: true)

### Available MCP Servers

- `atlassian` - Jira and Confluence integration
- `github` - GitHub API and PR management
- `grafana` - Metrics and monitoring
- `playwright` - Browser automation and UI testing
- `circleci` - CI/CD pipeline management
- `Ref` - Documentation reference lookup

## Usage Commands

```bash
# Import a specific recipe
ruly import --recipe workaxle-bug

# Squash a recipe for testing (run from temp directory)
cd $(mktemp -d)
ruly squash --recipe workaxle-testing

# List available recipes
ruly recipes

# Update installed ruly after changes
mise install ruby
```

## Key Achievements

- **85% token reduction** from ~15,000 tokens to ~2,000 tokens base usage
- **Conditional loading** based on file patterns and task profiles
- **MCP server integration** for automated tool availability
- **Task-specific recipes** for focused workflows

## Important Notes

1. When updating recipes, always update both the project and user config files
2. Test recipe changes using `ruly squash` in a temporary directory
3. Update the installed ruly binary after making changes to the gem
4. WorkAxle recipes follow a naming convention: `workaxle-[task]` (e.g., workaxle-bug, workaxle-testing)
5. The `workaxle-full` recipe exists for rare cases when complete documentation is needed
